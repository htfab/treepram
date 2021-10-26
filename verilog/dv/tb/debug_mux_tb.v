// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module debug_mux_tb();

parameter CORES=4;
parameter LOG_CORES=2;
parameter DATA_WIDTH=8;

reg [LOG_CORES-1:0] sel;
reg [4:0] addr;
reg we;
reg [DATA_WIDTH-1:0] wdata;
wire [DATA_WIDTH-1:0] rdata;
reg reg_stopped[CORES-1:0];
reg [DATA_WIDTH-1:0] reg_rdata[CORES-1:0];
wire [1:0] cpu_mode[CORES-1:0];
wire [3:0] reg_sel[CORES-1:0];
wire reg_we[CORES-1:0];
wire [DATA_WIDTH-1:0] reg_wdata[CORES-1:0];

wire [CORES-1:0] reg_stopped_raw;
wire [CORES*DATA_WIDTH-1:0] reg_rdata_raw;
wire [CORES*2-1:0] cpu_mode_raw;
wire [CORES*4-1:0] reg_sel_raw;
wire [CORES-1:0] reg_we_raw;
wire [CORES*DATA_WIDTH-1:0] reg_wdata_raw;

debug_mux #(
   .CORES(CORES),
   .LOG_CORES(LOG_CORES),
   .DATA_WIDTH(DATA_WIDTH)
) debug_mux_dut (
   .sel(sel),
   .addr(addr),
   .we(we),
   .wdata(wdata),
   .rdata(rdata),
   .reg_stopped(reg_stopped_raw),
   .reg_rdata(reg_rdata_raw),
   .cpu_mode(cpu_mode_raw),
   .reg_sel(reg_sel_raw),
   .reg_we(reg_we_raw),
   .reg_wdata(reg_wdata_raw)
);


generate genvar core;
for (core=0; core<CORES; core=core+1) begin:g_core
   assign reg_stopped_raw[core] = reg_stopped[core];
   assign reg_rdata_raw[core*DATA_WIDTH +: DATA_WIDTH] = reg_rdata[core];
   assign cpu_mode[core] = cpu_mode_raw[core*2 +: 2];
   assign reg_sel[core] = reg_sel_raw[core*4 +: 4];
   assign reg_we[core] = reg_we_raw[core];
   assign reg_wdata[core] = reg_wdata_raw[core*DATA_WIDTH +: DATA_WIDTH];
end
endgenerate

initial begin
   $monitor("time=%4t SEL=%b ADDR=%b WE=%b WDATA=%b rdata=%b, ST0=%b RD0=%b cm0=%b s0=%b we0=%b wd0=%b ST1=%b RD1=%b cm1=%b s1=%b we1=%b wd1=%b",
               $time, sel, addr, we, wdata, rdata, reg_stopped[0], reg_rdata[0], cpu_mode[0], reg_sel[0], reg_we[0], reg_wdata[0],
                                                   reg_stopped[1], reg_rdata[1], cpu_mode[1], reg_sel[1], reg_we[1], reg_wdata[1]);
   sel = 0;
   addr = 5'b01100;
   we = 0;
   wdata = 8'b10101010;
   reg_stopped[0] = 1;
   reg_stopped[1] = 0;
   reg_stopped[2] = 1;
   reg_stopped[3] = 0;
   reg_rdata[0] = 8'b11110000;
   reg_rdata[1] = 8'b11100001;
   reg_rdata[2] = 8'b11000011;
   reg_rdata[3] = 8'b10000111;

   #10
   sel = 1;
   we = 1;

   #10
   sel = 0;
   we = 0;
   addr = 5'b10000;

   #10
   sel = 1;
   we = 1;
   wdata = 8'b00000011;

   #10
   $stop;
end

endmodule

`default_nettype wire

