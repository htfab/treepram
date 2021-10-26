// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Instruction memory
*/

module instr_mem #(parameter DEPTH=128) (
   input clk,
   input rst_n,
   input [`PC_WIDTH-1:0] raddr,
   output [`INSTR_WIDTH-1:0] rdata,
   input we,
   input [`PC_WIDTH-1:0] waddr,
   input [`INSTR_WIDTH-1:0] wdata
);

reg [`INSTR_WIDTH-1:0] mem[DEPTH-1:0];

assign rdata = mem[raddr];

integer i;
always @ (posedge clk) begin
   if (!rst_n) begin
      for (i=0; i<DEPTH; i=i+1) begin
         mem[i] <= {(`INSTR_WIDTH){1'b0}};
      end
   end else begin
      if (we) mem[waddr] <= wdata;
   end
end

endmodule

`default_nettype wire

