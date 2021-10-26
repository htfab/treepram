// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module prog_mux_tb();

parameter CORES=4;
parameter LOG_CORES=2;
parameter PC_WIDTH=4;
parameter INSTR_WIDTH=8;

reg we;
reg [LOG_CORES-1:0] sel;
reg [PC_WIDTH-1:0] waddr;
reg [INSTR_WIDTH-1:0] wdata;
wire [CORES-1:0] cwe_raw;
wire [CORES*PC_WIDTH-1:0] cwaddr_raw;
wire [CORES*INSTR_WIDTH-1:0] cwdata_raw;

prog_mux #(
   .CORES(CORES),
   .LOG_CORES(LOG_CORES),
   .PC_WIDTH(PC_WIDTH),
   .INSTR_WIDTH(INSTR_WIDTH)
) prog_mux_dut (
   .we(we),
   .sel(sel),
   .waddr(waddr),
   .wdata(wdata),
   .cwe(cwe_raw),
   .cwaddr(cwaddr_raw),
   .cwdata(cwdata_raw)
);

wire cwe[CORES-1:0];
wire [PC_WIDTH-1:0] cwaddr[CORES-1:0];
wire [INSTR_WIDTH-1:0] cwdata[CORES-1:0];

generate genvar core;
for (core=0; core<CORES; core=core+1) begin:g_core
   assign cwe[core] = cwe_raw[core];
   assign cwaddr[core] = cwaddr_raw[core*PC_WIDTH +: PC_WIDTH];
   assign cwdata[core] = cwdata_raw[core*INSTR_WIDTH +: INSTR_WIDTH];
end
endgenerate

initial begin
   $monitor("time=%4t we=%d sel=%d waddr=%d wdata=%d cwe0=%d cwaddr0=%d cwdata0=%d cwe1=%d cwaddr1=%d cwdata1=%d",
               $time, we, sel, waddr, wdata, cwe[0], cwaddr[0], cwdata[0], cwe[1], cwaddr[1], cwdata[1]);

   we = 0;

   #10
   we = 1;
   sel = 0;
   waddr = 3;
   wdata = 11;

   #10
   we = 0;

   #10
   we = 1;
   sel = 1;
   waddr = 5;
   wdata = 25;

   #10
   sel = 0;
   waddr = 0;
   wdata = 1;

   #10
   $stop;
end

endmodule

`default_nettype wire

