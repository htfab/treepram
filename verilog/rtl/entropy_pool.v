// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Simple entropy pool, shifting a single bit into prng's in each clock cycle
*/

module entropy_pool (
   input clk,
   input rst_n,
   input[`WB_WIDTH-1:0] e_word,
   output e_bit
);

reg[`WB_WIDTH-1:0] e_pool;
wire[`WB_WIDTH-1:0] e_pool_mod;
assign {e_pool_mod, e_bit} = {1'b0, e_pool} ^ {e_word, 1'b0};

always @(posedge clk) begin
   if(!rst_n)
      e_pool <= 0;
   else
      e_pool <= e_pool_mod;
end

endmodule

`default_nettype wire

