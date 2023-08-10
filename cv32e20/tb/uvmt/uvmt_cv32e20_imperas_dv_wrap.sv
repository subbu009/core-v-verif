//
// Copyright 2022 OpenHW Group
// Copyright 2023 Imperas
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//


`ifndef __UVMT_CV32E20_IMPERAS_DV_WRAP_SV__
`define __UVMT_CV32E20_IMPERAS_DV_WRAP_SV__

`define DUT_PATH dut_wrap.cv32e20_top_i
`define RVFI_IF  `DUT_PATH

`define STRINGIFY(x) `"x`"

////////////////////////////////////////////////////////////////////////////
// Assign the rvvi CSR values from RVFI - CSR = (wdata & wmask) | (rdata & ~wmask)
////////////////////////////////////////////////////////////////////////////
`define RVVI_SET_CSR(CSR_ADDR, CSR_NAME) \
    bit csr_``CSR_NAME``_wb; \
    wire [31:0] csr_``CSR_NAME``_w; \
    wire [31:0] csr_``CSR_NAME``_r; \
    assign csr_``CSR_NAME``_w = `RVFI_IF.rvfi_csr_``CSR_NAME``_wdata &   `RVFI_IF.rvfi_csr_``CSR_NAME``_wmask; \
    assign csr_``CSR_NAME``_r = `RVFI_IF.rvfi_csr_``CSR_NAME``_rdata & ~(`RVFI_IF.rvfi_csr_``CSR_NAME``_wmask); \
    assign rvvi.csr[0][0][``CSR_ADDR]    = csr_``CSR_NAME``_w | csr_``CSR_NAME``_r; \
    assign rvvi.csr_wb[0][0][``CSR_ADDR] = csr_``CSR_NAME``_wb; \
    always @(rvvi.csr[0][0][``CSR_ADDR]) begin \
        csr_``CSR_NAME``_wb = 1; \
    end \
    always @(posedge rvvi.clk) begin \
        if (`RVFI_IF.rvfi_valid && csr_``CSR_NAME``_wb) begin \
            csr_``CSR_NAME``_wb = 0; \
        end \
    end

`define RVVI_SET_CSR_VEC(CSR_ADDR, CSR_NAME, CSR_ID) \
    bit csr_``CSR_NAME````CSR_ID``_wb; \
    wire [31:0] csr_``CSR_NAME````CSR_ID``_w; \
    wire [31:0] csr_``CSR_NAME````CSR_ID``_r; \
    assign csr_``CSR_NAME````CSR_ID``_w = `RVFI_IF.rvfi_csr_``CSR_NAME``_wdata[``CSR_ID] &   `RVFI_IF.rvfi_csr_``CSR_NAME``_wmask[``CSR_ID]; \
    assign csr_``CSR_NAME````CSR_ID``_r = `RVFI_IF.rvfi_csr_``CSR_NAME``_rdata[``CSR_ID] & ~(`RVFI_IF.rvfi_csr_``CSR_NAME``_wmask[``CSR_ID]); \
    assign rvvi.csr[0][0][``CSR_ADDR]    = csr_``CSR_NAME````CSR_ID``_w | csr_``CSR_NAME````CSR_ID``_r; \
    assign rvvi.csr_wb[0][0][``CSR_ADDR] = csr_``CSR_NAME````CSR_ID``_wb; \
    always @(rvvi.csr[0][0][``CSR_ADDR]) begin \
        csr_``CSR_NAME````CSR_ID``_wb = 1; \
    end \
    always @(posedge rvvi.clk) begin \
        if (`RVFI_IF.rvfi_valid && csr_``CSR_NAME````CSR_ID``_wb) begin \
            csr_``CSR_NAME````CSR_ID``_wb = 0; \
        end \
    end

////////////////////////////////////////////////////////////////////////////
// Assign the NET IRQ values from the core irq inputs
////////////////////////////////////////////////////////////////////////////
`define RVVI_WRITE_IRQ(IRQ_NAME, IRQ_IDX) \
    wire   irq_``IRQ_NAME; \
    assign irq_``IRQ_NAME = `DUT_PATH.irq_i[IRQ_IDX]; \
    always @(irq_``IRQ_NAME) begin \
        void'(rvvi.net_push(`STRINGIFY(``IRQ_NAME), irq_``IRQ_NAME)); \
    end

`include "csr_macros.svh" // CSR address

///////////////////////////////////////////////////////////////////////////////
// Module wrapper for Imperas DV.
////////////////////////////////////////////////////////////////////////////
// `define USE_ISS
`ifdef USE_ISS

`include "idv/idv.svh" // located in $IMPERAS_HOME/ImpProprietary/include/host

module uvmt_cv32e20_imperas_dv_wrap
  import uvm_pkg::*;
  import idvPkg::*;
  import rvviApiPkg::*;
  #(
     parameter FPU   = 0,
     parameter ZFINX = 0
    )

    (
        rvviTrace  rvvi // RVVI SystemVerilog Interface
    );

    trace2log       idv_trace2log(rvvi);

    trace2api #(
        .CMP_PC      (1),
        .CMP_INS     (1),
        .CMP_GPR     (1),
        .CMP_FPR     (0),
        .CMP_VR      (0),
        .CMP_CSR     (0)
    )
    trace2api(rvvi);

    trace2cov       idv_trace2cov(rvvi);

    string info_tag = "ImperasDV_wrap";

    ////////////////////////////////////////////////////////////////////////////
    // Adopted from:
    // ImperasDV/examples/openhwgroup_cv32e40x/systemverilog/cv32e40x_testbench.sv
    //
    // InstrunctionBusFault(48) is in fact a TRAP which is derived externally
    // This is strange as other program TRAPS are derived by the model, for now
    // We have to ensure we do not step the REF model for this TRAP as it will
    // Step too far. So instead we block it as being VALID, but pass on the
    // signals.
    // maybe we need a different way to communicate this to the model, for
    // instance the ability to register a callback on fetch, in order to assert
    // this signal.
    ////////////////////////////////////////////////////////////////////////////
    assign rvvi.clk            = `RVFI_IF.clk_i;
    assign rvvi.valid[0][0]    = `RVFI_IF.rvfi_valid;
    assign rvvi.order[0][0]    = `RVFI_IF.rvfi_order;
    assign rvvi.insn[0][0]     = `RVFI_IF.rvfi_insn;
    assign rvvi.trap[0][0]     = `RVFI_IF.rvfi_trap;
    assign rvvi.intr[0][0]     = `RVFI_IF.rvfi_intr;
//    assign rvvi.mode[0][0]     = `RVFI_IF.rvfi_mode;
//    assign rvvi.ixl[0][0]      = `RVFI_IF.rvfi_ixl;
    assign rvvi.pc_rdata[0][0] = `RVFI_IF.rvfi_pc_rdata;
    assign rvvi.pc_wdata[0][0] = `RVFI_IF.rvfi_pc_wdata;

//    `RVVI_SET_CSR( `CSR_MSTATUS_ADDR,       mstatus       )
//    `RVVI_SET_CSR( `CSR_MISA_ADDR,          misa          )
//    `RVVI_SET_CSR( `CSR_MIE_ADDR,           mie           )
//    `RVVI_SET_CSR( `CSR_MTVEC_ADDR,         mtvec         )
//    `RVVI_SET_CSR( `CSR_MCOUNTINHIBIT_ADDR, mcountinhibit )
//    `RVVI_SET_CSR( `CSR_MSCRATCH_ADDR,      mscratch      )
//    `RVVI_SET_CSR( `CSR_MEPC_ADDR,          mepc          )
//    `RVVI_SET_CSR( `CSR_MCAUSE_ADDR,        mcause        )
//    //  `RVVI_SET_CSR( `CSR_MTVAL_ADDR,         mtval         )
//    `RVVI_SET_CSR( `CSR_MIP_ADDR,           mip           )
//    //  `RVVI_SET_CSR( `CSR_MCYCLE_ADDR,        mcycle        )
//    `RVVI_SET_CSR( `CSR_MINSTRET_ADDR,      minstret      )
//    //  `RVVI_SET_CSR( `CSR_MCYCLEH_ADDR,       mcycleh       )
//    //  `RVVI_SET_CSR( `CSR_MINSTRETH_ADDR,     minstreth     )
//    `RVVI_SET_CSR( `CSR_MVENDORID_ADDR,     mvendorid     )
//    `RVVI_SET_CSR( `CSR_MARCHID_ADDR,       marchid       )
    //  `RVVI_SET_CSR( `CSR_MIMPID_ADDR,        mimpid        )
//    `RVVI_SET_CSR( `CSR_MHARTID_ADDR,       mhartid       )
//
//    //  `RVVI_SET_CSR( `CSR_TSELECT_ADDR,       tselect       )
//    `RVVI_SET_CSR( `CSR_DCSR_ADDR,          dcsr          )
//    `RVVI_SET_CSR( `CSR_DPC_ADDR,           dpc           )
//    `RVVI_SET_CSR_VEC(`CSR_DSCRATCH0_ADDR, dscratch, 0)
//    `RVVI_SET_CSR_VEC(`CSR_DSCRATCH1_ADDR, dscratch, 1)
//    `RVVI_SET_CSR_VEC(`CSR_TDATA1_ADDR, tdata, 1)
//    `RVVI_SET_CSR_VEC(`CSR_TDATA2_ADDR, tdata, 2)
//    `RVVI_SET_CSR( `CSR_TINFO_ADDR,         tinfo         )
//
//
//    `RVVI_SET_CSR(`CSR_FFLAGS_ADDR, fflags)
//    `RVVI_SET_CSR(`CSR_FRM_ADDR   , frm   )
//    `RVVI_SET_CSR(`CSR_FCSR_ADDR  , fcsr  )
//
//    `RVVI_SET_CSR(`CSR_LPCOUNT0_ADDR  , lpcount0  )
//    `RVVI_SET_CSR(`CSR_LPSTART0_ADDR  , lpstart0  )
//    `RVVI_SET_CSR(`CSR_LPEND0_ADDR    , lpend0    )
//
//    `RVVI_SET_CSR(`CSR_LPCOUNT1_ADDR  , lpcount1  )
//    `RVVI_SET_CSR(`CSR_LPSTART1_ADDR  , lpstart1  )
//    `RVVI_SET_CSR(`CSR_LPEND1_ADDR    , lpend1    )
    ////////////////////////////////////////////////////////////////////////////
    // Assign the RVVI GPR registers
    ////////////////////////////////////////////////////////////////////////////
    bit [31:0] XREG[32];
    genvar gi;
    generate
        for(gi=0; gi<32; gi++) begin
            assign rvvi.x_wdata[0][0][gi] = XREG[gi];
        end
    endgenerate

    always @(*) begin
        int i;
        for (i=1; i<32; i++) begin
            XREG[i] = 32'b0;
            if (`RVFI_IF.rvfi_rd_addr==5'(i))
            XREG[i] = `RVFI_IF.rvfi_rd_wdata;
        end
    end

    assign rvvi.x_wb[0][0] = (1 << `RVFI_IF.rvfi_rd_addr);

//    ////////////////////////////////////////////////////////////////////////////
//    // Assign the RVVI F GPR registers
//    ////////////////////////////////////////////////////////////////////////////
//    bit [31:0] FREG[32];
//
//    bit is_f_reg [1:0];
//
//    assign is_f_reg[0] = `RVFI_IF.rvfi_frd_wvalid[0];
//    assign is_f_reg[1] = `RVFI_IF.rvfi_frd_wvalid[1];
//
//    int f_reg_addr [1:0];
//    assign f_reg_addr[0] = `RVFI_IF.rvfi_frd_addr[0];
//    assign f_reg_addr[1] = `RVFI_IF.rvfi_frd_addr[1];
//
//    genvar fgi;
//    generate
//        for(fgi=0; fgi<32; fgi++) begin
//            assign rvvi.f_wdata[0][0][fgi] = FREG[fgi];
//        end
//    endgenerate
//
//    always @(*) begin
//        int i;
//        for (i=0; i<32; i++) begin
//            FREG[i] = 32'b0;
//            if (is_f_reg[0] & (`RVFI_IF.rvfi_frd_addr[0]==5'(i)))
//            FREG[i] = `RVFI_IF.rvfi_frd_wdata[0];
//            if (is_f_reg[1] & (`RVFI_IF.rvfi_frd_addr[1]==5'(i)))
//            FREG[i] = `RVFI_IF.rvfi_frd_wdata[1];
//        end
//    end
//
//    assign rvvi.f_wb[0][0] = (is_f_reg[0] << f_reg_addr[0] | is_f_reg[1] << f_reg_addr[1]);
//
//    ////////////////////////////////////////////////////////////////////////////
//    // DEBUG REQUESTS,
//    ////////////////////////////////////////////////////////////////////////////
//    logic debug_req_i;
//    assign debug_req_i = `DUT_PATH.debug_req_i;
//    always @(debug_req_i) begin
//        void'(rvvi.net_push("haltreq", debug_req_i));
//    end
//
//    ////////////////////////////////////////////////////////////////////////////
//    // INTERRUPTS
//    // assert when MIP or cause bit
//    // negate when posedge clk && valid=1 && debug=0
//    ////////////////////////////////////////////////////////////////////////////
//    `RVVI_WRITE_IRQ(MSWInterrupt,        3)
//    `RVVI_WRITE_IRQ(MTimerInterrupt,     7)
//    `RVVI_WRITE_IRQ(MExternalInterrupt, 11)
//    `RVVI_WRITE_IRQ(LocalInterrupt0,    16)
//    `RVVI_WRITE_IRQ(LocalInterrupt1,    17)
//    `RVVI_WRITE_IRQ(LocalInterrupt2,    18)
//    `RVVI_WRITE_IRQ(LocalInterrupt3,    19)
//    `RVVI_WRITE_IRQ(LocalInterrupt4,    20)
//    `RVVI_WRITE_IRQ(LocalInterrupt5,    21)
//    `RVVI_WRITE_IRQ(LocalInterrupt6,    22)
//    `RVVI_WRITE_IRQ(LocalInterrupt7,    23)
//    `RVVI_WRITE_IRQ(LocalInterrupt8,    24)
//    `RVVI_WRITE_IRQ(LocalInterrupt9,    25)
//    `RVVI_WRITE_IRQ(LocalInterrupt10,   26)
//    `RVVI_WRITE_IRQ(LocalInterrupt11,   27)
//    `RVVI_WRITE_IRQ(LocalInterrupt12,   28)
//    `RVVI_WRITE_IRQ(LocalInterrupt13,   29)
//    `RVVI_WRITE_IRQ(LocalInterrupt14,   30)
//    `RVVI_WRITE_IRQ(LocalInterrupt15,   31)

    /////////////////////////////////////////////////////////////////////////////
    // REF control
    /////////////////////////////////////////////////////////////////////////////
    task ref_init;
    string test_program_elf;
    reg [31:0] hart_id;

    // Select processor
    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_VENDOR,  "openhwgroup.ovpworld.org"));
    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_NAME,    "riscv"));
    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_VARIANT, "CV32E20"));
    // Worst case propagation of events 4 retirements (actually 3 observed)
    void'(rvviRefConfigSetInt(IDV_CONFIG_MAX_NET_LATENCY_RETIREMENTS, 4));
    // Redirect stdout to parent systemverilog simulator
    void'(rvviRefConfigSetInt(IDV_CONFIG_REDIRECT_STDOUT, RVVI_TRUE));

    // Initialize REF and load the test-program into it's memory (do this before initializing the DUT).
    // TODO: is this the best place for this?
    if (!rvviVersionCheck(RVVI_API_VERSION)) begin
        `uvm_fatal(info_tag, $sformatf("Expecting RVVI API version %0d.", RVVI_API_VERSION))
    end
    // Test-program must have been compiled before we got here...
    if ($value$plusargs("elf_file=%s", test_program_elf)) begin
        `uvm_info(info_tag, $sformatf("ImperasDV loading test_program %0s", test_program_elf), UVM_NONE)
        if (!rvviRefInit(test_program_elf)) begin
            `uvm_fatal(info_tag, "rvviRefInit failed")
        end
        else begin
            `uvm_info(info_tag, "rvviRefInit() succeed", UVM_NONE)
        end
    end
    else begin
        `uvm_fatal(info_tag, "No test_program specified")
    end

    hart_id = 32'h0000_0000;

    
    void'(rvviRefCsrSetVolatile(hart_id, `CSR_CYCLE_ADDR        ));

    void'(rvviRefCsrSetVolatile(hart_id, `CSR_INSTRET_ADDR      ));

    void'(rvviRefCsrSetVolatile(hart_id, `CSR_MCYCLE_ADDR       ));

    // cannot predict this register due to latency between
    // pending and taken
    void'(rvviRefCsrSetVolatile(hart_id, `CSR_MIP_ADDR          ));
    void'(rvviRefCsrSetVolatileMask(hart_id, `CSR_DCSR_ADDR, 'h8));

//    // define asynchronous grouping
//    // Interrupts
//    rvviRefNetGroupSet(rvviRefNetIndexGet("MSWInterrupt"),        1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("MTimerInterrupt"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("MExternalInterrupt"),  1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt0"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt1"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt2"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt3"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt4"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt5"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt6"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt7"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt8"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt9"),     1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt10"),    1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt11"),    1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt12"),    1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt13"),    1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt14"),    1);
//    rvviRefNetGroupSet(rvviRefNetIndexGet("LocalInterrupt15"),    1);

//  rvviRefNetGroupSet(rvviRefNetIndexGet("InstructionBusFault"), 2);

    // Debug
//    rvviRefNetGroupSet(rvviRefNetIndexGet("haltreq"),             4);

//    void'(rvviRefMemorySetVolatile('h15001000, 'h15001007)); //TODO: deal with int return value
  endtask // ref_init
endmodule : uvmt_cv32e20_imperas_dv_wrap
`endif  // USE_ISS

`endif // __UVMT_CV32E20_IMPERAS_DV_WRAP_SV__
