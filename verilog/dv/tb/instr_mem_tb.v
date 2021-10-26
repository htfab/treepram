// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module instr_mem_tb();

parameter PC_WIDTH = 4;
parameter INSTR_WIDTH = 8;
parameter DEPTH = 16;

reg clk;
reg rst_n;
reg [PC_WIDTH-1:0] raddr;
wire [INSTR_WIDTH-1:0] rdata;
reg we;
reg [PC_WIDTH-1:0] waddr;
reg [INSTR_WIDTH-1:0] wdata;

instr_mem #(
   .INSTR_WIDTH(INSTR_WIDTH),
   .PC_WIDTH(PC_WIDTH),
   .DEPTH(DEPTH)
) instr_mem_dut (
   .clk(clk),
   .rst_n(rst_n),
   .raddr(raddr),
   .rdata(rdata),
   .we(we),
   .waddr(waddr),
   .wdata(wdata)
);

always #5 clk = ~clk;

initial begin
   $monitor("time=%4t rstn=%1b we=%1b waddr=%4b wdata=%8b raddr=%4b rdata=%8b", $time, rst_n, we, waddr, wdata, raddr, rdata);
   clk <= 0;
   rst_n <= 0;
   we <= 0;
   waddr <= 0;
   wdata <= 1;
   raddr <= 0;
   #500 $display("");
   rst_n <= 0;
   #500 $display("");
   rst_n <= 0;
   #500 $finish;
end

always @(posedge clk) begin
   if (!rst_n) begin
      rst_n <= 1;
   end else begin
      if (we) begin
         waddr <= waddr + 1;
         wdata <= wdata + 1;
      end
      we <= !we;
      raddr <= raddr + 1;
   end
end

endmodule

`default_nettype wire

