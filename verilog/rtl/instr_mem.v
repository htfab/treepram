// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Instruction memory
*/

module instr_mem (
   input clk,
   input rst_n,
   input [`CORES*`PC_WIDTH-1:0] raddr,
   output [`CORES*`INSTR_WIDTH-1:0] rdata,
   input [`CORES-1:0] we,
   input [`CORES*`PC_WIDTH-1:0] waddr,
   input [`CORES*`INSTR_WIDTH-1:0] wdata
);

localparam CORES_RNDUP = 1 << `LOG_CORES;

generate genvar core;
for(core=0; core<`CORES; core=core+1) begin:g_core

   localparam DEPTH_MULT = (core + CORES_RNDUP) & ~(core + CORES_RNDUP-1);
   // e.g. for 8 cores, depths are multiplied by 8, 1, 2, 1, 4, 1, 2, 1
   // so that we have a few cores that accept longer programs but the total
   // memory required is still kept reasonably low
   
   localparam DEPTH = `INSTR_DEPTH * DEPTH_MULT;

   wire [`PC_WIDTH-1:0] craddr = raddr[core*`PC_WIDTH +: `PC_WIDTH];
   wire cwe = we[core];
   wire [`PC_WIDTH-1:0] cwaddr = waddr[core*`PC_WIDTH +: `PC_WIDTH];
   wire [`INSTR_WIDTH-1:0] cwdata = wdata[core*`INSTR_WIDTH +: `INSTR_WIDTH];

   reg [`INSTR_WIDTH-1:0] mem[DEPTH-1:0];

   wire [`INSTR_WIDTH-1:0] crdata = mem[craddr];
   assign rdata[core*`INSTR_WIDTH +: `INSTR_WIDTH] = crdata;

   integer i;
   always @ (posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<DEPTH; i=i+1) begin
            mem[i] <= {(`INSTR_WIDTH){1'b0}};
         end
      end else begin
         if (cwe) mem[cwaddr] <= cwdata;
      end
   end

end
endgenerate

endmodule

`default_nettype wire

