// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Pseudorandom number generator using a Fibonacci-style XNOR linear feedback shift register

STATE_BITS = number of bits for prng state
POLYNOMIAL = bit mask used for feedback, should be chosen so that the prng repeats ifself after 2^(STATE_BITS-1) cycles
STATE_INIT = used to seed the prng on reset
OUTPUT_BITS = number of bits shifted out every clock cycle
*/

module prng #(parameter STATE_BITS = 4, POLYNOMIAL = 4'b1001, STATE_INIT = 4'b0000, OUTPUT_BITS = 2) (
   input clk,
   input rst_n,
   input entropy,    // optional external entropy for more randomness
   output [OUTPUT_BITS-1:0] random
);

localparam SCRAMBLE_CYCLES = STATE_BITS;
reg [STATE_BITS-1:0] state;

generate genvar shift;

// shift register for generating next OUTPUT_BITS states
for (shift=0; shift<OUTPUT_BITS; shift=shift+1) begin:g_shift
   wire [STATE_BITS-1:0] prev_state;
   wire feedback;
   if (shift == 0) begin:i_first
      assign prev_state = state;
      assign feedback = ^(prev_state & POLYNOMIAL) ^ entropy;
   end else begin:i_nfirst
      assign prev_state = g_shift[shift-1].new_state;
      assign feedback = ^(prev_state & POLYNOMIAL);
   end
   wire [STATE_BITS-1:0] new_state = {prev_state[STATE_BITS-2:0], ~feedback};
   assign random[OUTPUT_BITS-shift-1] = prev_state[STATE_BITS-1];
end
wire [STATE_BITS-1:0] final_state = g_shift[OUTPUT_BITS-1].new_state;

// reuse the same shift register to shift out a couple of bits in the beginning so that
// we can use a very simple seed without affecting the quality of the first few cycles
// (this happens at synth time, so it's practically free)
for (shift=0; shift<SCRAMBLE_CYCLES; shift=shift+1) begin:g_scramble
   wire [STATE_BITS-1:0] prev_state;
   if (shift == 0) begin:i_first
      assign prev_state = STATE_INIT;
   end else begin:i_nfirst
      assign prev_state = g_scramble[shift-1].new_state;
   end
   wire feedback = ^(prev_state & POLYNOMIAL);
   wire [STATE_BITS-1:0] new_state = {prev_state[STATE_BITS-2:0], ~feedback};
end
wire [STATE_BITS-1:0] scrambled_init = g_scramble[SCRAMBLE_CYCLES-1].new_state;

endgenerate

always @(posedge clk) begin
   if (!rst_n) begin
      state <= scrambled_init;
   end else begin
      state <= final_state;
   end
end

endmodule

`default_nettype wire

