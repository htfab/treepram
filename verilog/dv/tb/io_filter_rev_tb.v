// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module io_filter_rev_tb();

parameter IO_PINS = 4;
parameter DATA_WIDTH = 8;

reg clk;
reg rst_n;
reg [IO_PINS-1:0] pin_dir;
wire [IO_PINS-1:0] pin_data_in_raw;
wire [IO_PINS-1:0] pin_data_out_raw;
wire [IO_PINS+2-1:0] port_active_in_raw;
wire [IO_PINS+2-1:0] port_active_out_raw;
wire [(IO_PINS+2)*DATA_WIDTH-1:0] port_data_in_raw;
wire [(IO_PINS+2)*DATA_WIDTH-1:0] port_data_out_raw;

io_filter_rev #(
   .IO_PINS(IO_PINS),
   .DATA_WIDTH(DATA_WIDTH)
) io_filter_rev_dut (
   .clk(clk),
   .rst_n(rst_n),
   .pin_dir(pin_dir),
   .pin_data_in(pin_data_in_raw),
   .pin_data_out(pin_data_out_raw),
   .port_active_in(port_active_in_raw),
   .port_active_out(port_active_out_raw),
   .port_data_in(port_data_in_raw),
   .port_data_out(port_data_out_raw)
);

// The testbench acts as the "external world" for the io filter, so it simulates both the cpu/memory part
// and the peripherals. An "output" message is one sent from the cpu/memory to the peripherals which means
// the testbench ports act as output and the pins act as input. Conversely, an "input" message is one coming
// from the peripherals to the cpu/memory where testbench pins will act as output and ports as input.

wire [IO_PINS-1:0] pin_data_out;
reg [IO_PINS+2-1:0] port_active_out;
reg [(IO_PINS+2)*DATA_WIDTH-1:0] port_data_out;

reg [IO_PINS-1:0] pin_data_in;
wire [IO_PINS+2-1:0] port_active_in;
wire [(IO_PINS+2)*DATA_WIDTH-1:0] port_data_in;

generate genvar pin;
for (pin=0; pin<IO_PINS; pin=pin+1) begin:g_pin
   // output
   assign port_active_out_raw[pin] = port_active_out[pin];
   assign port_data_out_raw[pin*DATA_WIDTH +: DATA_WIDTH] = port_data_out[pin*DATA_WIDTH +: DATA_WIDTH];
   assign pin_data_out = pin_data_out_raw;
   // input
   assign pin_data_in_raw[pin] = pin_data_in[pin];
   assign port_active_in[pin] = port_active_in_raw[pin];
   assign port_data_in[pin*DATA_WIDTH +: DATA_WIDTH] = port_data_in_raw[pin*DATA_WIDTH +: DATA_WIDTH];
end
endgenerate
// output
assign port_active_out_raw[IO_PINS +: 2] = {1'b0, port_active_out[IO_PINS]};
assign port_data_out_raw[IO_PINS*DATA_WIDTH +: 2*DATA_WIDTH] = {{(DATA_WIDTH){1'b0}}, port_data_out[IO_PINS*DATA_WIDTH +: DATA_WIDTH]};
// input
assign port_active_in[IO_PINS +: 2] = {port_active_in_raw[IO_PINS+1], 1'b0};
assign port_data_in[IO_PINS*DATA_WIDTH +: 2*DATA_WIDTH] = {port_data_in_raw[(IO_PINS+1)*DATA_WIDTH +: DATA_WIDTH], {(DATA_WIDTH){1'b0}}};

always #5 clk = ~clk;

initial begin
   $monitor("time %4d pin_data_in %4b pin_data_out %4b port_active_in %6b port_active_out %6b port_data_in %24b port_data_out %24b",
               $time, pin_data_in_raw, pin_data_out_raw, port_active_in_raw, port_active_out_raw, port_data_in_raw, port_data_out_raw);
   clk <= 0;
   rst_n <= 0;
   #40
   rst_n <= 1;
   pin_dir <= 4'b1010;
   port_active_out <= 6'b0;
   port_data_out <= 48'b0;
   pin_data_in <= 4'b0;
   #40
   pin_data_in <= 4'b0001;
   #40
   port_active_out <= 6'b000100;
   port_data_out <= 48'b00000000_00000000_00000000_11111111_00000000_11111111;
   #10 port_active_out <= 6'b0;
   #30
   port_active_out <= 6'b010000;
   port_data_out <= 48'b00000000_00000001_00000000_00000000_00000000_00000000;
   #10 port_active_out <= 6'b0;
   #30
   port_active_out <= 6'b010001;
   port_data_out <= 48'b00000000_00000011_00000000_00000000_00000000_00000000;
   #10 port_active_out <= 6'b0;
   #30
   $stop;
end

endmodule

`default_nettype wire

