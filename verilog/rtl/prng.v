// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Pseudorandom number generator using a Fibonacci-style XNOR linear feedback shift register
*/

module prng (
   input clk,
   input rst_n,
   input [`PRNG_STATE_BITS-1:0] polynomial,  // bit mask used for feedback, should be chosen so that
                                             //   the prng repeats ifself after 2^(`PRNG_STATE_BITS-1) cycles
   input [`PRNG_STATE_BITS-1:0] state_init,  // used to seed the prng on reset
   input entropy,                            // optional external entropy for more randomness
   output [`DATA_WIDTH-1:0] random
);

localparam SCRAMBLE_CYCLES = `PRNG_STATE_BITS;
reg [`PRNG_STATE_BITS-1:0] state;

generate genvar shift;

// shift register for generating next `DATA_WIDTH states
for (shift=0; shift<`DATA_WIDTH; shift=shift+1) begin:g_shift
   wire [`PRNG_STATE_BITS-1:0] prev_state;
   wire feedback;
   if (shift == 0) begin:i_first
      assign prev_state = state;
      assign feedback = ^(prev_state & polynomial) ^ entropy;
   end else begin:i_nfirst
      assign prev_state = g_shift[shift-1].new_state;
      assign feedback = ^(prev_state & polynomial);
   end
   wire [`PRNG_STATE_BITS-1:0] new_state = {prev_state[`PRNG_STATE_BITS-2:0], ~feedback};
   assign random[`DATA_WIDTH-shift-1] = prev_state[`PRNG_STATE_BITS-1];
end
wire [`PRNG_STATE_BITS-1:0] final_state = g_shift[`DATA_WIDTH-1].new_state;

// reuse the same shift register to shift out a couple of bits in the beginning so that
// we can use a very simple seed without affecting the quality of the first few cycles
// (for constant seeds this happens at synth time, so it's practically free)
for (shift=0; shift<SCRAMBLE_CYCLES; shift=shift+1) begin:g_scramble
   wire [`PRNG_STATE_BITS-1:0] prev_state;
   if (shift == 0) begin:i_first
      assign prev_state = state_init;
   end else begin:i_nfirst
      assign prev_state = g_scramble[shift-1].new_state;
   end
   wire feedback = ^(prev_state & polynomial);
   wire [`PRNG_STATE_BITS-1:0] new_state = {prev_state[`PRNG_STATE_BITS-2:0], ~feedback};
end
wire [`PRNG_STATE_BITS-1:0] scrambled_init = g_scramble[SCRAMBLE_CYCLES-1].new_state;

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

