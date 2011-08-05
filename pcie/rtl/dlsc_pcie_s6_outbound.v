
module dlsc_pcie_s6_outbound #(
    parameter ASYNC         = 0,                // axi_clk asynchronous to pcie_clk
    parameter ADDR          = 32,               // width of AXI address bus
    parameter LEN           = 4,                // width of AXI length field
    parameter WRITE_EN      = 1,                // enable outbound write path
    parameter WRITE_SIZE    = 128,              // max write size (in bytes; power of 2)
    parameter WRITE_MOT     = 16,               // max outstanding write transactions
    parameter READ_EN       = 1,                // enable outbound read path
    parameter READ_MOT      = 16,               // max outstanding read transactions
    parameter READ_CPLH     = 8,                // max receive buffer completion header space
    parameter READ_CPLD     = 64,               // max receive buffer completion data space    
    parameter READ_SIZE     = (READ_CPLD*16),   // size of read buffer (in bytes; power of 2)
    parameter READ_TIMEOUT  = 625000,           // read completion timeout (default is 10ms at 62.5 MHz)
    parameter TAG           = 5,                // PCIe tag bits
    parameter FCHB          = 8,                // bits for flow control header credits
    parameter FCDB          = 12                // bits for flow control data credits
) (
    
    // ** AXI **
    
    // System
    input   wire                axi_clk,         // == pcie_clk when !ASYNC
    input   wire                axi_rst,         // == pcie_rst when !ASYNC

    // Read Command
    output  wire                axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [ADDR-1:0]  axi_ar_addr,
    input   wire    [LEN-1:0]   axi_ar_len,

    // Read response
    input   wire                axi_r_ready,
    output  wire                axi_r_valid,
    output  wire                axi_r_last,
    output  wire    [31:0]      axi_r_data,
    output  wire    [1:0]       axi_r_resp,
    
    // Write Command
    output  wire                axi_aw_ready,
    input   wire                axi_aw_valid,
    input   wire    [ADDR-1:0]  axi_aw_addr,
    input   wire    [LEN-1:0]   axi_aw_len,

    // Write Data
    output  wire                axi_w_ready,
    input   wire                axi_w_valid,
    input   wire                axi_w_last,
    input   wire    [3:0]       axi_w_strb,
    input   wire    [31:0]      axi_w_data,

    // Write Response
    input   wire                axi_b_ready,
    output  wire                axi_b_valid,
    output  wire    [1:0]       axi_b_resp,

    // Control/Status
    input   wire                axi_rd_disable,
    input   wire                axi_wr_disable,
    output  wire                axi_rd_busy,
    output  wire                axi_wr_busy,
    
    // ** PCIe **

    // System
    input   wire                pcie_clk,
    input   wire                pcie_rst,

    // Status
    output  wire                pcie_tlp_pending,        // transactions pending

    // Config
    input   wire    [2:0]       pcie_max_payload_size,
    input   wire    [2:0]       pcie_max_read_request,
    input   wire                pcie_rcb,                // read completion boundary
    input   wire                pcie_dma_en,             // bus-mastering enabled
    
    // PCIe ID
    input   wire    [7:0]       pcie_bus_number,
    input   wire    [4:0]       pcie_dev_number,
    input   wire    [2:0]       pcie_func_number,
    
    // PCIe link partner credit info
    output  wire    [2:0]       pcie_fc_sel,             // selects 'transmit credits available'
    input   wire    [FCHB-1:0]  pcie_fc_ph,              // posted header credits
    input   wire    [FCDB-1:0]  pcie_fc_pd,              // posted data credits

    // TLP receive input (completions only)
    output  wire                pcie_rx_ready,
    input   wire                pcie_rx_valid,
    input   wire    [31:0]      pcie_rx_data,
    input   wire                pcie_rx_last,
    input   wire                pcie_rx_err,
    
    // TLP output
    input   wire                pcie_tx_ready,
    output  wire                pcie_tx_valid,
    output  wire    [31:0]      pcie_tx_data,
    output  wire                pcie_tx_last,

    // Error reporting
    input   wire                pcie_err_ready,
    output  wire                pcie_err_valid,
    output  wire                pcie_err_unexpected,
    output  wire                pcie_err_timeout
);

`include "dlsc_clog2.vh"

localparam READ_BUFA = `dlsc_clog2(READ_SIZE/4);


// ** Synchronized PCIe signals **
    
// Status
wire            tlp_pending;        // transactions pending

// Config
wire [2:0]      max_payload_size;   // (cfg_dcommand[7:5])
wire [2:0]      max_read_request;   // (cfg_dcommand[14:12])
wire            rcb;                // read completion boundary (cfg_lcommand[3])
wire            dma_en;             // bus-mastering enabled (cfg_command[2])

// PCIe ID
wire [7:0]      bus_number;
wire [4:0]      dev_number;
wire [2:0]      func_number;

// PCIe link partner credit info
assign          pcie_fc_sel     = 3'b100;   // transmit credits available
wire [FCHB-1:0] fc_ph;              // posted header credits
wire [FCDB-1:0] fc_pd;              // posted data credits

// TLP receive input (completions only)
wire            rx_ready;
wire            rx_valid;
wire [31:0]     rx_data;
wire            rx_last;
wire            rx_err;

// TLP output
wire            tx_ready;
wire            tx_valid;
wire [31:0]     tx_data;
wire            tx_last;

// Error reporting
wire            err_ready;
wire            err_valid;
wire            err_unexpected;
wire            err_timeout;

// Local control
wire            bridge_rst;
wire            axi_disable;
wire            axi_flush;
wire            rd_disable;
wire            wr_disable;

// rd/wr_disable are always synchronized (APB may be async)
dlsc_syncflop #(
    .DATA       ( 2 ),
    .RESET      ( 2'b11 )
) dlsc_syncflop_disable (
    .in         ( { axi_rd_disable, axi_wr_disable } ),
    .clk        ( axi_clk ),
    .rst        ( bridge_rst ),
    .out        ( {     rd_disable,     wr_disable } )
);

generate
if(ASYNC==0) begin:GEN_SYNC

    assign          pcie_tlp_pending    = tlp_pending;

    assign          max_payload_size    = pcie_max_payload_size;
    assign          max_read_request    = pcie_max_read_request;
    assign          rcb                 = pcie_rcb;
    assign          dma_en              = pcie_dma_en;

    assign          bus_number          = pcie_bus_number;
    assign          dev_number          = pcie_dev_number;
    assign          func_number         = pcie_func_number;

    assign          fc_ph               = pcie_fc_ph;
    assign          fc_pd               = pcie_fc_pd;

    assign          pcie_rx_ready       = rx_ready;
    assign          rx_valid            = pcie_rx_valid;
    assign          rx_data             = pcie_rx_data;
    assign          rx_last             = pcie_rx_last;
    assign          rx_err              = pcie_rx_err;

    assign          tx_ready            = pcie_tx_ready;
    assign          pcie_tx_valid       = tx_valid;
    assign          pcie_tx_data        = tx_data;
    assign          pcie_tx_last        = tx_last;

    assign          err_ready           = pcie_err_ready;
    assign          pcie_err_valid      = err_valid;
    assign          pcie_err_unexpected = err_unexpected;
    assign          pcie_err_timeout    = err_timeout;

    assign          bridge_rst          = pcie_rst;
    assign          axi_disable         = 1'b0;
    assign          axi_flush           = 1'b0;

end else begin:GEN_ASYNC

    wire            cross_rst;

    dlsc_pcie_s6_rstcontrol dlsc_pcie_s6_rstcontrol_inst (
        .pcie_rst       ( pcie_rst ),
        .clk            ( axi_clk ),
        .rst            ( axi_rst ),
        .cross_rst      ( cross_rst ),
        .bridge_rst     ( bridge_rst ),
        .axi_busy       ( axi_rd_busy || axi_wr_busy ),
        .axi_disable    ( axi_disable ),
        .axi_flush      ( axi_flush )
    );

    // status to PCIe controller
    dlsc_syncflop #(
        .DATA           ( 1 ),
        .RESET          ( 1'b0 )
    ) dlsc_syncflop_tlp_pending (
        .in             ( tlp_pending ),
        .clk            ( pcie_clk ),
        .rst            ( pcie_rst ),
        .out            ( pcie_tlp_pending )
    );

    // config from PCIe controller
    dlsc_domaincross #(
        .DATA           ( 3+3+1+1+8+5+3+FCHB+FCDB )
    ) dlsc_domaincross_inst (
        .in_clk         ( pcie_clk ),
        .in_rst         ( pcie_rst ),
        .in_data        ( {
            pcie_max_payload_size,
            pcie_max_read_request,
            pcie_rcb,
            pcie_dma_en,
            pcie_bus_number,
            pcie_dev_number,
            pcie_func_number,
            pcie_fc_ph,
            pcie_fc_pd } ),
        .out_clk        ( axi_clk ),
        .out_rst        ( cross_rst ),
        .out_data       ( {
            max_payload_size,
            max_read_request,
            rcb,
            dma_en,
            bus_number,
            dev_number,
            func_number,
            fc_ph,
            fc_pd } )
    );

    // TLPs to PCIe controller
    dlsc_pcie_s6_tlpfifo #(
        .DATA           ( 32 ),
        .ADDR           ( 4 )
    ) dlsc_pcie_s6_tlpfifo_tx (
        .wr_clk         ( axi_clk ),
        .wr_rst         ( cross_rst ),
        .wr_ready       ( tx_ready ),
        .wr_valid       ( tx_valid ),
        .wr_last        ( tx_last ),
        .wr_data        ( tx_data ),
        .rd_clk         ( pcie_clk ),
        .rd_rst         ( pcie_rst ),
        .rd_ready       ( pcie_tx_ready ),
        .rd_valid       ( pcie_tx_valid ),
        .rd_last        ( pcie_tx_last ),
        .rd_data        ( pcie_tx_data )
    );

    if(READ_EN!=0) begin:GEN_ASYNC_READ

        // TLPs from PCIe controller
        // (only used by read path)
        dlsc_pcie_s6_tlpfifo #(
            .DATA           ( 33 ),
            .ADDR           ( 4 )
        ) dlsc_fifo_s6_tlpfifo_rx (
            .wr_clk         ( pcie_clk ),
            .wr_rst         ( pcie_rst ),
            .wr_ready       ( pcie_rx_ready ),
            .wr_valid       ( pcie_rx_valid ),
            .wr_last        ( pcie_rx_last ),
            .wr_data        ( { pcie_rx_err, pcie_rx_data } ),
            .rd_clk         ( axi_clk ),
            .rd_rst         ( cross_rst ),
            .rd_ready       ( rx_ready ),
            .rd_valid       ( rx_valid ),
            .rd_last        ( rx_last ),
            .rd_data        ( { rx_err, rx_data } )
        );

        // Errors to PCIe controller
        // (only used by read path)
        dlsc_domaincross_rvh #(
            .DATA           ( 2 ),
            .RESET          ( 2'b00 ),
            .RESET_ON_TRANSFER ( 1 )
        ) dlsc_domaincross_rvh_err (
            .in_clk         ( axi_clk ),
            .in_rst         ( cross_rst ),
            .in_ready       ( err_ready ),
            .in_valid       ( err_valid ),
            .in_data        ( { err_unexpected, err_timeout } ),
            .out_clk        ( pcie_clk ),
            .out_rst        ( pcie_rst ),
            .out_ready      ( pcie_err_ready ),
            .out_valid      ( pcie_err_valid ),
            .out_data       ( { pcie_err_unexpected, pcie_err_timeout } )
        );

    end else begin:GEN_ASYNC_NOREAD

        assign          pcie_rx_ready       = 1'b0;
        assign          tx_valid            = 1'b0;
        assign          tx_data             = 32'd0;
        assign          tx_last             = 1'b0;

        assign          err_ready           = 1'b0;
        assign          pcie_err_valid      = 1'b0;
        assign          pcie_err_unexpected = 1'b0;
        assign          pcie_err_timeout    = 1'b0;

    end

end
endgenerate


// ** Read **
    
wire            rd_tlp_h_ready;
wire            rd_tlp_h_valid;
wire [ADDR-1:2] rd_tlp_h_addr;
wire [9:0]      rd_tlp_h_len;
wire [TAG-1:0]  rd_tlp_h_tag;
wire [3:0]      rd_tlp_h_be_first;
wire [3:0]      rd_tlp_h_be_last;

generate
if(READ_EN) begin:GEN_READ

    dlsc_pcie_s6_outbound_read #(
        .ADDR               ( ADDR ),
        .LEN                ( LEN ),
        .MOT                ( READ_MOT ),
        .BUFA               ( READ_BUFA ),
        .TAG                ( TAG ),
        .CPLH               ( READ_CPLH ),
        .CPLD               ( READ_CPLD ),
        .FCHB               ( FCHB ),
        .FCDB               ( FCDB ),
        .TIMEOUT            ( READ_TIMEOUT )
    ) dlsc_pcie_s6_outbound_read_inst (
        .clk                ( axi_clk ),
        .rst                ( bridge_rst ),
        .axi_ar_ready       ( axi_ar_ready ),
        .axi_ar_valid       ( axi_ar_valid ),
        .axi_ar_addr        ( axi_ar_addr ),
        .axi_ar_len         ( axi_ar_len ),
        .axi_r_ready        ( axi_r_ready ),
        .axi_r_valid        ( axi_r_valid ),
        .axi_r_last         ( axi_r_last ),
        .axi_r_data         ( axi_r_data ),
        .axi_r_resp         ( axi_r_resp ),
        .tlp_pending        ( tlp_pending ),
        .max_read_request   ( max_read_request ),
        .rcb                ( rcb ),
        .dma_en             ( dma_en ),
        .rx_ready           ( rx_ready ),
        .rx_valid           ( rx_valid ),
        .rx_data            ( rx_data ),
        .rx_last            ( rx_last ),
        .rx_err             ( rx_err ),
        .rd_tlp_h_ready     ( rd_tlp_h_ready ),
        .rd_tlp_h_valid     ( rd_tlp_h_valid ),
        .rd_tlp_h_addr      ( rd_tlp_h_addr ),
        .rd_tlp_h_len       ( rd_tlp_h_len ),
        .rd_tlp_h_tag       ( rd_tlp_h_tag ),
        .rd_tlp_h_be_first  ( rd_tlp_h_be_first ),
        .rd_tlp_h_be_last   ( rd_tlp_h_be_last ),
        .err_ready          ( err_ready ),
        .err_valid          ( err_valid ),
        .err_unexpected     ( err_unexpected ),
        .err_timeout        ( err_timeout ),
        .rd_busy            ( axi_rd_busy ),
        .rd_disable         ( axi_disable || rd_disable ),
        .rd_flush           ( axi_flush )
    );

end else begin:GEN_NOREAD

    assign          axi_ar_ready        = 1'b0;
    assign          axi_r_valid         = 1'b0;
    assign          axi_r_last          = 1'b0;
    assign          axi_r_data          = 32'd0;
    assign          axi_r_resp          = 2'b00;

    assign          tlp_pending         = 1'b0;

    assign          err_valid           = 1'b0;
    assign          err_unexpected      = 1'b0;
    assign          err_timeout         = 1'b0;

    assign          rd_tlp_h_valid      = 1'b0;
    assign          rd_tlp_h_addr       = {(ADDR-2){1'b0}};
    assign          rd_tlp_h_len        = 10'd0;
    assign          rd_tlp_h_tag        = {TAG{1'b0}};
    assign          rd_tlp_h_be_first   = 4'd0;
    assign          rd_tlp_h_be_last    = 4'd0;

    assign          axi_rd_busy         = 1'b0;

end
endgenerate


// ** Write **

wire            wr_tlp_h_ready;
wire            wr_tlp_h_valid;
wire [ADDR-1:2] wr_tlp_h_addr;
wire [9:0]      wr_tlp_h_len;
wire [3:0]      wr_tlp_h_be_first;
wire [3:0]      wr_tlp_h_be_last;
wire            wr_tlp_d_ready;
wire            wr_tlp_d_valid;
wire [31:0]     wr_tlp_d_data;

generate
if(WRITE_EN) begin:GEN_WRITE

    dlsc_pcie_s6_outbound_write #(
        .ADDR               ( ADDR ),
        .LEN                ( LEN ),
        .MOT                ( WRITE_MOT ),
        .MAX_SIZE           ( WRITE_SIZE ),
        .FCHB               ( FCHB ),
        .FCDB               ( FCDB )
    ) dlsc_pcie_s6_outbound_write_inst (
        .clk                ( axi_clk ),
        .rst                ( bridge_rst ),
        .axi_aw_ready       ( axi_aw_ready ),
        .axi_aw_valid       ( axi_aw_valid ),
        .axi_aw_addr        ( axi_aw_addr ),
        .axi_aw_len         ( axi_aw_len ),
        .axi_w_ready        ( axi_w_ready ),
        .axi_w_valid        ( axi_w_valid ),
        .axi_w_last         ( axi_w_last ),
        .axi_w_strb         ( axi_w_strb ),
        .axi_w_data         ( axi_w_data ),
        .axi_b_ready        ( axi_b_ready ),
        .axi_b_valid        ( axi_b_valid ),
        .axi_b_resp         ( axi_b_resp ),
        .max_payload_size   ( max_payload_size ),
        .dma_en             ( dma_en ),
        .fc_sel             (  ),
        .fc_ph              ( fc_ph ),
        .fc_pd              ( fc_pd ),
        .wr_tlp_h_ready     ( wr_tlp_h_ready ),
        .wr_tlp_h_valid     ( wr_tlp_h_valid ),
        .wr_tlp_h_addr      ( wr_tlp_h_addr ),
        .wr_tlp_h_len       ( wr_tlp_h_len ),
        .wr_tlp_h_be_first  ( wr_tlp_h_be_first ),
        .wr_tlp_h_be_last   ( wr_tlp_h_be_last ),
        .wr_tlp_d_ready     ( wr_tlp_d_ready ),
        .wr_tlp_d_valid     ( wr_tlp_d_valid ),
        .wr_tlp_d_data      ( wr_tlp_d_data ),
        .wr_busy            ( axi_wr_busy ),
        .wr_disable         ( axi_disable || wr_disable ),
        .wr_flush           ( axi_flush )
    );

end else begin:GEN_NOWRITE

    assign          axi_aw_ready        = 1'b0;
    assign          axi_w_ready         = 1'b0;
    assign          axi_b_valid         = 1'b0;
    assign          axi_b_resp          = 2'b00;

    assign          wr_tlp_h_valid      = 1'b0;
    assign          wr_tlp_h_addr       = {(ADDR-2){1'b0}};
    assign          wr_tlp_h_len        = 10'd0;
    assign          wr_tlp_h_be_first   = 4'd0;
    assign          wr_tlp_h_be_last    = 4'd0;

    assign          wr_tlp_d_valid      = 1'b0;
    assign          wr_tlp_d_data       = 32'd0;

    assign          axi_wr_busy         = 1'b0;

end
endgenerate


// ** Address Translator (TODO) **

wire            trans_req;
wire [ADDR-1:2] trans_req_addr;
reg             trans_ack       = 0;
reg  [63:2]     trans_ack_addr  = 0;
reg             trans_ack_64    = 1'b0;

always @(posedge axi_clk) begin
    trans_ack       <= trans_req;
    trans_ack_addr  <= { {(64-ADDR){1'b0}}, trans_req_addr[ADDR-1:2] };
    trans_ack_64    <= 1'b0;
end


// ** TLP **

dlsc_pcie_s6_outbound_tlp #(
    .ADDR               ( ADDR ),
    .TAG                ( TAG )
) dlsc_pcie_s6_outbound_tlp_inst (
    .clk                ( axi_clk ),
    .rst                ( bridge_rst ),
    .trans_req          ( trans_req ),
    .trans_req_addr     ( trans_req_addr ),
    .trans_ack          ( trans_ack ),
    .trans_ack_addr     ( trans_ack_addr ),
    .trans_ack_64       ( trans_ack_64 ),
    .rd_tlp_h_ready     ( rd_tlp_h_ready ),
    .rd_tlp_h_valid     ( rd_tlp_h_valid ),
    .rd_tlp_h_addr      ( rd_tlp_h_addr ),
    .rd_tlp_h_len       ( rd_tlp_h_len ),
    .rd_tlp_h_tag       ( rd_tlp_h_tag ),
    .rd_tlp_h_be_first  ( rd_tlp_h_be_first ),
    .rd_tlp_h_be_last   ( rd_tlp_h_be_last ),
    .wr_tlp_h_ready     ( wr_tlp_h_ready ),
    .wr_tlp_h_valid     ( wr_tlp_h_valid ),
    .wr_tlp_h_addr      ( wr_tlp_h_addr ),
    .wr_tlp_h_len       ( wr_tlp_h_len ),
    .wr_tlp_h_be_first  ( wr_tlp_h_be_first ),
    .wr_tlp_h_be_last   ( wr_tlp_h_be_last ),
    .wr_tlp_d_ready     ( wr_tlp_d_ready ),
    .wr_tlp_d_valid     ( wr_tlp_d_valid ),
    .wr_tlp_d_data      ( wr_tlp_d_data ),
    .tlp_ready          ( tx_ready ),
    .tlp_valid          ( tx_valid ),
    .tlp_data           ( tx_data ),
    .tlp_last           ( tx_last ),
    .bus_number         ( bus_number ),
    .dev_number         ( dev_number ),
    .func_number        ( func_number )
);

endmodule

