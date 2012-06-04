//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_csr_tlm_slave_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<bool>        csr_cmd_valid;
    sc_core::sc_in<bool>        csr_cmd_write;
    sc_core::sc_in<uint32_t>    csr_cmd_addr;
    sc_core::sc_in<uint32_t>    csr_cmd_data;
    sc_core::sc_out<bool>       csr_rsp_valid;
    sc_core::sc_out<bool>       csr_rsp_error;
    sc_core::sc_out<uint32_t>   csr_rsp_data;

    dlsc_tlm_initiator_nb<uint32_t>::socket_type socket;
    
    /*AUTOMETHODS*/

private:
    dlsc_csr_tlm_slave_template<uint32_t,uint32_t> *slave;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    slave = new dlsc_csr_tlm_slave_template<uint32_t,uint32_t>("slave");

    slave->clk.bind(clk);
    slave->rst.bind(rst);
    
    slave->csr_cmd_valid.bind(csr_cmd_valid);
    slave->csr_cmd_write.bind(csr_cmd_write);
    slave->csr_cmd_addr.bind(csr_cmd_addr);
    slave->csr_cmd_data.bind(csr_cmd_data);
    slave->csr_rsp_valid.bind(csr_rsp_valid);
    slave->csr_rsp_error.bind(csr_rsp_error);
    slave->csr_rsp_data.bind(csr_rsp_data);

    slave->socket.bind(socket);
}

/*AUTOTRACE(__MODULE__)*/

