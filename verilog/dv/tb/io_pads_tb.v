// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module io_pads_tb();

parameter IO_PINS=16;
parameter IO_PADS=38;
parameter LOGIC_PROBES=128;
parameter FIRST_PAD=12;

reg wb_clk_i;
reg wb_rst_i;
reg [LOGIC_PROBES-1:0] la_data_in;
wire [LOGIC_PROBES-1:0] la_data_out;
reg [LOGIC_PROBES-1:0] la_oenb;
reg [IO_PADS-1:0] io_in;
wire [IO_PADS-1:0] io_out;
wire [IO_PADS-1:0] io_oeb;
wire clk;
wire rst_hard_n;
wire rst_soft_n;
wire rst_prng_n;
wire [IO_PINS-1:0] pin_dir;
wire [IO_PINS-1:0] pin_data_in;
reg [IO_PINS-1:0] pin_data_out;
reg cfg_we;
reg cfg_addr;
reg [IO_PINS-1:0] cfg_wdata;

io_pads #(
   .IO_PINS(IO_PINS),
   .IO_PADS(IO_PADS),
   .LOGIC_PROBES(LOGIC_PROBES),
   .FIRST_PAD(FIRST_PAD)
) io_pads_dut (
   .wb_clk_i(wb_clk_i),
   .wb_rst_i(wb_rst_i),
   .la_data_in(la_data_in),
   .la_data_out(la_data_out),
   .la_oenb(la_oenb),
   .io_in(io_in),
   .io_out(io_out),
   .io_oeb(io_oeb),
   .clk(clk),
   .rst_hard_n(rst_hard_n),
   .rst_soft_n(rst_soft_n),
   .rst_prng_n(rst_prng_n),
   .pin_dir(pin_dir),
   .pin_data_in(pin_data_in),
   .pin_data_out(pin_data_out),
   .cfg_we(cfg_we),
   .cfg_addr(cfg_addr),
   .cfg_wdata(cfg_wdata)
);

always #5 wb_clk_i = ~wb_clk_i;

initial begin
   $monitor("time %4t lado %b io %b ioe %b clk %b rh %b rs %b rp %b pd %b pi %b pm %b sd %b",
      $time, la_data_out, io_out, io_oeb, clk, rst_hard_n, rst_soft_n, rst_prng_n, pin_dir, pin_data_in, io_pads_dut.programming, io_pads_dut.saved_dir);
   wb_clk_i = 0;
   wb_rst_i = 1;
   la_data_in = 128'b0;
   la_oenb = ~128'b0;
   io_in = 38'b0;
   pin_data_out = 16'b0;
   cfg_we = 0;
   cfg_addr = 0;
   cfg_wdata = 16'b0;
   #10
   wb_rst_i = 0;
   #30
   $display("clock & reset tests");
   la_oenb[0] = 0;
   #30
   la_data_in[0] = 1;
   #30
   la_data_in[0] = 0;
   #30
   la_oenb[0] = 1;
   la_oenb[1] = 0;
   la_data_in[1] = 0;
   #30
   la_oenb[1] = 1;
   #30
   la_oenb[2] = 0;
   #30
   la_oenb[2] = 1;
   #30
   la_oenb[3] = 0;
   #30
   la_oenb[3] = 1;
   #30
   wb_rst_i = 1;
   #30
   wb_rst_i = 0;
   #30
   la_oenb[4:1] = 3'b000;
   la_data_in[4:1] = 3'b111;
   wb_rst_i = 1;
   #30
   la_oenb[4:1] = 3'b111;
   la_data_in[4:1] = 3'b000;
   wb_rst_i = 0;
   #10
   $display("wb mux config test");
   cfg_we = 1;
   cfg_addr = 0;
   cfg_wdata = 1;
   #10
   cfg_wdata = 0;
   #10
   cfg_addr = 1;
   cfg_wdata = 16'b1111111100000000;
   #10
   cfg_we = 0;
   #10
   $display("io pin & pad tests");
   $display("%d", io_pads_dut.LA_PAD);
   io_in = 38'b111010101010101010111111111111;
   #10
   pin_data_out = 16'b1100110011001100;
   #10
   la_oenb[8 +: 8] = 8'b00000000;
   la_data_in[8 +: 8] = 8'b00001111;
   #10
   la_oenb[8 +: 8] = 8'b11111111;
   la_data_in[8 +: 8] = 8'b00000000;
   #10
   la_oenb[24 +: 8] = 8'b00000000;
   la_data_in[24 +: 8] = 8'b11110000;
   #10
   la_oenb[24 +: 8] = 8'b11111111;
   la_data_in[24 +: 8] = 8'b00000000;
   #10
   la_oenb[52 +: 8] = 8'b00000000;
   la_data_in[52 +: 8] = 8'b11110000;
   #10
   la_oenb[52 +: 8] = 8'b11111111;
   la_data_in[52 +: 8] = 8'b00000000;
   #10
   $stop;
end

endmodule

`default_nettype wire

