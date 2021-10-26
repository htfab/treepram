// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
IO filter with reversed pin order
*/

module io_filter_rev (
   input clk,
   input rst_n,
   input [`IO_PINS-1:0] pin_dir,            // 0=input, 1=output
   input [`IO_PINS-1:0] pin_data_in,        // input for both mem_mesh & io_filter
   output [`IO_PINS-1:0] pin_data_out,      // output for both mem_mesh & io_filter
   output [`IO_PINS+2-1:0] port_active_in,  // input for mem_mesh, output for io_filter
   input [`IO_PINS+2-1:0] port_active_out,  // output for mem_mesh, input for io_filter
   output [(`IO_PINS+2)*`DATA_WIDTH-1:0] port_data_in,
   input [(`IO_PINS+2)*`DATA_WIDTH-1:0] port_data_out
);

wire [`IO_PINS-1:0] pin_dir_rev;
wire [`IO_PINS-1:0] pin_data_in_rev;
wire [`IO_PINS-1:0] pin_data_out_rev;

io_filter io_filter_inst (
   .clk(clk),
   .rst_n(rst_n),
   .pin_dir(pin_dir_rev),
   .pin_data_in(pin_data_in_rev),
   .pin_data_out(pin_data_out_rev),
   .port_active_in(port_active_in),
   .port_active_out(port_active_out),
   .port_data_in(port_data_in),
   .port_data_out(port_data_out)
);

generate genvar pin;
   for (pin=0; pin<`IO_PINS; pin=pin+1) begin:g_pin
      localparam rpin = `IO_PINS-1-pin;
      assign pin_dir_rev[pin] = pin_dir[rpin];
      assign pin_data_in_rev[pin] = pin_data_in[rpin];
      assign pin_data_out[pin] = pin_data_out_rev[rpin];
   end
endgenerate

endmodule

`default_nettype wire

