// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Fully combinatorial programming multiplexer
*/

module prog_mux (
   input we,
   input [`LOG_CORES-1:0] sel,
   input [`PC_WIDTH-1:0] waddr,
   input [`INSTR_WIDTH-1:0] wdata,
   output [`CORES-1:0] cwe,
   output [`CORES*`PC_WIDTH-1:0] cwaddr,
   output [`CORES*`INSTR_WIDTH-1:0] cwdata
);

generate genvar core;
for (core=0; core<`CORES; core=core+1) begin:g_core
   wire active = we && sel==core;
   assign cwe[core] = active;
   assign cwaddr[core*`PC_WIDTH +: `PC_WIDTH] = {(`PC_WIDTH){active}} & waddr;
   assign cwdata[core*`INSTR_WIDTH +: `INSTR_WIDTH] = {(`INSTR_WIDTH){active}} & wdata;
end
endgenerate

endmodule

`default_nettype wire

