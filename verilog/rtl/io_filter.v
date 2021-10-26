// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
IO filter

Interfaces the io pins of the chip to the io ports of mem_mesh.

An io port is created for each individual pin where the lowest bit sent on the port is forwarded
to the pin and a bit coming from the pin is stretched to the full port width.

Two additional io ports are created by joining together all input pins and all output pins respectively,
right-aligned and zero-padded.

Pins send and receive continuous streams of bits while io ports only fire on changes.
Writing ports corresponding to individual pins override bits of the joined output port.

We assume `IO_PINS <= `DATA_WIDTH. Alternatively we could modify the code to use more than one joined
port per direction.
*/

module io_filter (
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

reg [`IO_PINS-1:0] saved_in;
reg [`IO_PINS-1:0] saved_out;

// input
wire [`IO_PINS-1:0] input_indiv = pin_data_in;                             // select input pins
wire [`IO_PINS-1:0] input_indiv_active = pin_data_in ^ saved_in;           // a pin is active if it changed from the last state
wire input_joined_active = |input_indiv_active;                            // update the joined port if any of the pins changed
wire [`IO_PINS-1:0] input_joined;
pin_compress comp (                                                        // compress input bits together
   .data(input_indiv),
   .mask(~pin_dir),
   .result(input_joined)
);

// input
assign port_active_in[`IO_PINS +: 2] = {input_joined_active, 1'b0};        // assign the joined ports & their active states
assign port_data_in[`IO_PINS*`DATA_WIDTH +: 2*`DATA_WIDTH] = {input_joined, {(`DATA_WIDTH){1'b0}}};
// output
wire [`IO_PINS-1:0] output_indiv;
wire [`IO_PINS-1:0] output_indiv_active;
generate genvar pin;
   for (pin=0; pin<`IO_PINS; pin=pin+1) begin:g_pin
      // input
      assign port_active_in[pin] = input_indiv_active[pin];                // assign the individual ports & their active states
      assign port_data_in[pin*`DATA_WIDTH +: `DATA_WIDTH] = {(`DATA_WIDTH){input_indiv[pin]}};
      // output
      assign pin_data_out[pin] = saved_out[pin];                           // output pins keep their state between writes
      assign output_indiv_active[pin] = port_active_out[pin];              // get pins & their active states from the individual output ports
      assign output_indiv[pin] = port_data_out[pin*`DATA_WIDTH];
   end
endgenerate

// output
wire [`IO_PINS-1:0] output_joined = port_data_out[`IO_PINS*`DATA_WIDTH +: `DATA_WIDTH]; // get pins & their active state from the joined output port
wire output_joined_active = port_active_out[`IO_PINS];
wire [`IO_PINS-1:0] output_decomp;
pin_decompress decomp (                                                    // decompress output pins to their respective bit positions
   .data(output_joined),
   .mask(pin_dir),
   .result(output_decomp)
);

// consolidate pins set through joined & individual ports (individual ports have priority)
wire [`IO_PINS-1:0] output_mixed = (output_indiv_active & output_indiv) | (~output_indiv_active & output_decomp);
wire [`IO_PINS-1:0] output_mixed_active = output_indiv_active | {(`IO_PINS){output_joined_active}};

integer i;
always @(posedge clk) begin
   if (!rst_n) begin
      saved_in <= 0;
      saved_out <= 0;
   end else begin
      for (i=0; i<`IO_PINS; i=i+1) begin
         // active outputs change the saved state in order to keep being sent
         if (output_mixed_active[i]) saved_out[i] <= output_mixed[i];
         // inputs are only active for a single cycle while they differ from their saved state
         saved_in[i] <= input_indiv[i];
      end
   end
end

endmodule

`default_nettype wire

