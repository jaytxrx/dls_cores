// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// Unsigned integer divider which can accept a new input every CYCLES clock cycles.
//
// Delay through module is:
//  For CYCLES ==  1, delay is QB+1 cycles (fully pipelined)
//  For CYCLES >= QB, delay is QB+2 cycles (fully sequential)
//  For other cases , delay is QB+4 cycles (hybrid)
//

module dlsc_divu #(
    parameter CYCLES    = 1,    // cycles allowed per division
    parameter NB        = 8,    // total bits for numerator/dividend
    parameter DB        = NB,   // total bits for denominator/divisor
    parameter QB        = NB,   // total bits for quotient
    parameter NFB       = 0,    // fractional bits for numerator
    parameter DFB       = 0,    // fractional bits for denominator
    parameter QFB       = 0     // fractional bits for quotient
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // input
    input   wire                    in_valid,
    input   wire    [NB-1:0]        in_num,
    input   wire    [DB-1:0]        in_den,

    // output
    output  wire                    out_valid,
    output  wire    [QB-1:0]        out_quo
);

`include "dlsc_util.vh"

`dlsc_static_assert( QB <= (NB+DB) )

`dlsc_static_assert( NFB <= NB )
`dlsc_static_assert( DFB <= DB )
`dlsc_static_assert( QFB <= QB )

localparam Q0       = QB-NB+NFB-DFB;
localparam QLSB     = Q0-QFB;
localparam QSKIP    = (QLSB<0) ? (0-QLSB) : 0;  // MSbits of quotient to skip (<= DB )
localparam QWASTE   = (QLSB>0) ? (  QLSB) : 0;  // LSbits of quotient to throw away (< QB; ideally 0)

`dlsc_static_assert( QSKIP <= DB )
`dlsc_static_assert( QWASTE < QB )

// For NB = 6, DB = 4:
//
//        0 D D D D
// Q[ 5]: 0 0 0 0 N N N N N N
// Q[ 4]: 0 0 0 N N N N N N 0
// Q[ 3]: 0 0 N N N N N N 0 0
// Q[ 2]: 0 N N N N N N 0 0 0
// Q[ 1]: N N N N N N 0 0 0 0
// Q[ 0]: N N N N N 0 0 0 0 0
// Q[-1]: N N N N S 0 0 0 0 0
// Q[-2]: N N N S S 0 0 0 0 0
// Q[-3]: N N S S S 0 0 0 0 0
// Q[-4]: N S S S S 0 0 0 0 0

wire [QB-1:0] out_quo_pre;
assign out_quo = { {QWASTE{1'b0}} , out_quo_pre[QB-1:QWASTE] };

generate
if(CYCLES<=1) begin:GEN_PIPELINED

    dlsc_divu_pipe #(
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_pipe (
        .clk        ( clk ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_quo    ( out_quo_pre )
    );

    dlsc_pipedelay_rst #(
        .DELAY      ( QB+1 ),
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_pipedelay_rst (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_data    ( in_valid ),
        .out_data   ( out_valid )
    );

end else if(CYCLES>=QB) begin:GEN_SEQUENTIAL

    dlsc_divu_seq #(
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_seq (
        .clk        ( clk ),
        .in_valid   ( in_valid ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_quo    ( out_quo_pre )
    );

    dlsc_pipedelay_rst #(
        .DELAY      ( QB+2 ),
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_pipedelay_rst (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_data    ( in_valid ),
        .out_data   ( out_valid )
    );

end else begin:GEN_HYBRID

    dlsc_divu_hybrid #(
        .CYCLES     ( CYCLES ),
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_hybrid (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_valid   ( in_valid ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_valid  ( out_valid ),
        .out_quo    ( out_quo_pre )
    );

end
endgenerate

endmodule

