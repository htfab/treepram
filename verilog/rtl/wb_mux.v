// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Wishbone multiplexer to process messages from Caravel

We use wishbone in classic mode with the simplest possible interface:
- all operations complete in a single cycle
- input is valid if STB_I && CYC_I is asserted
- for valid inputs, ACK_O is held asserted
- if WE_I is asserted, a write operation is performed using ADR_I and DAT_I
- if WE_I is negated, a read operation is performed using ADR_I with the result in DAT_O
- all other ports are unused

The wishbone bus width (WB_WIDTH below) is fixed to 32 by the platform and our code
assumes that all other widths fit into it.

This module (like other muxes in this project) is fully combinatorial.
Registered logic happens in connected cpu cores, instruction memories and the entropy pool.
Therefore CLK_I and RST_I are not directly used here. However, it is used in the
parent module as the main clock and reset signal and thus affect the modules
connected to the other interfaces.
*/

module wb_mux #(parameter
   LOG_CORES=3,
   PC_WIDTH=8,
   INSTR_WIDTH=32,
   DATA_WIDTH=16,
   IO_PINS=16,
   WB_WIDTH=32
) (
   // wishbone interface
   //input wb_clk_i,          // wb clock
   //input wb_rst_i,          // wb reset, active high
   input wb_stb_i,            // wb strobe signal
   input wb_cyc_i,            // wb cycle signal, sending on the bus requires wb_stb_i && wb_cyc_i
   input wb_we_i,             // wb write enable signal, 0=input 1=output
   input [WB_WIDTH-1:0] wb_adr_i,         // wb address
   input [WB_WIDTH-1:0] wb_dat_i,         // wb input data
   output wbs_ack_o,                      // wb acknowledge
   output [WB_WIDTH-1:0] wbs_dat_o,       // wb output data
   // programmer interface
   output prog_we,
   output [LOG_CORES-1:0] prog_sel,
   output [PC_WIDTH-1:0] prog_waddr,
   output [INSTR_WIDTH-1:0] prog_wdata,
   // pads & soft reset interface
   output pads_we,
   output pads_waddr,
   output [IO_PINS-1:0] pads_wdata,
   // debugger interface
   output [LOG_CORES-1:0] debug_sel,
   output [4:0] debug_addr,
   output debug_we,
   output [DATA_WIDTH-1:0] debug_wdata,
   input [DATA_WIDTH-1:0] debug_rdata,
   // entropy pool interface
   output[WB_WIDTH-1:0] entropy_word
);

// minimal wishbone logic
wire valid = wb_stb_i && wb_cyc_i;
assign wbs_ack_o = valid;

// interface selection
wire[1:0] interface = wb_adr_i[WB_WIDTH-2 +: 2];
wire if_prog = valid && interface == 2'b00;
wire if_pads = valid && interface == 2'b01;
wire if_debug = valid && interface == 2'b10;
wire if_entropy = valid && interface == 2'b11;

// programmer interface
assign prog_we = if_prog && wb_we_i;
assign {prog_sel, prog_waddr} = prog_we ? wb_adr_i[WB_WIDTH-3:0] : 0;
assign prog_wdata = prog_we ? wb_dat_i : 0;

// pads interface
assign pads_we = if_pads && wb_we_i;
assign pads_waddr = pads_we ? wb_adr_i[WB_WIDTH-3:0] : 0;
assign pads_wdata = pads_we ? wb_dat_i : 0;

// debugger interface, input
assign {debug_sel, debug_addr} = if_debug ? wb_adr_i[WB_WIDTH-3:0] : 0;
assign debug_we = if_debug && wb_we_i;
assign debug_wdata = debug_we ? wb_dat_i : 0;

// debugger interface, output
assign wbs_dat_o = (if_debug && !wb_we_i) ? debug_rdata : 0;

// entropy pool interface
assign entropy_word = (if_entropy && wb_we_i) ? wb_dat_i : 0;

endmodule

`default_nettype wire

