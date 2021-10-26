// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Fully combinatorial debugging multiplexer

Sends messages to cpu cores to run, stop or single step.
Queries or modifies registers and status flags.
*/

module debug_mux (
   input [`LOG_CORES-1:0] sel,                // controller interface
   input [4:0] addr,                          // 0xxxx affects status register xxxx, 10000 affects running/stopped state
   input we,
   input [`DATA_WIDTH-1:0] wdata,
   output [`DATA_WIDTH-1:0] rdata,
   input [`CORES-1:0] reg_stopped,            // interface towards cpu cores
   input [`CORES*`DATA_WIDTH-1:0] reg_rdata,
   output [`CORES*2-1:0] cpu_mode,
   output [`CORES*4-1:0] reg_sel,
   output [`CORES-1:0] reg_we,
   output [`CORES*`DATA_WIDTH-1:0] reg_wdata
);

wire reg_stopped_i[`CORES-1:0];
wire [`DATA_WIDTH-1:0] reg_rdata_i[`CORES-1:0];
wire [1:0] cpu_mode_i[`CORES-1:0];
wire [3:0] reg_sel_i[`CORES-1:0];
wire reg_we_i[`CORES-1:0];
wire [`DATA_WIDTH-1:0] reg_wdata_i[`CORES-1:0];

wire cc_mode;
wire [3:0] cc_sel;
assign {cc_mode, cc_sel} = addr;
assign rdata = cc_mode ? reg_stopped_i[sel] : reg_rdata_i[sel];

generate genvar core;
for(core=0; core<`CORES; core=core+1) begin:g_core
   assign reg_stopped_i[core] = reg_stopped[core];
   assign reg_rdata_i[core] = reg_rdata[core*`DATA_WIDTH +: `DATA_WIDTH];
   assign cpu_mode[core*2 +: 2] = cpu_mode_i[core];
   assign reg_sel[core*4 +: 4] = reg_sel_i[core];
   assign reg_we[core] = reg_we_i[core];
   assign reg_wdata[core*`DATA_WIDTH +: `DATA_WIDTH] = reg_wdata_i[core];

   wire cur = sel == core;
   assign cpu_mode_i[core] = (cur && we && cc_mode) ? wdata : 2'b00;
   assign reg_sel_i[core] = (cur && !cc_mode) ? cc_sel : 4'b0000;
   assign reg_we_i[core] = cur && we && !cc_mode;
   assign reg_wdata_i[core] = (cur && we && !cc_mode) ? wdata : 0;
end
endgenerate

endmodule

`default_nettype wire

