// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module prng_tb();

parameter STATE_BITS = 4;
parameter POLYNOMIAL = 4'b1100;
parameter STATE_INIT = 4'b0000;
parameter OUTPUT_BITS = 2;

reg clk;
reg rst_n;
wire [OUTPUT_BITS-1:0] random;

prng #(
   .STATE_BITS(STATE_BITS),
   .POLYNOMIAL(POLYNOMIAL),
   .STATE_INIT(STATE_INIT),
   .OUTPUT_BITS(OUTPUT_BITS)
) prng_dut (
   .clk(clk),
   .rst_n(rst_n),
   .entropy(1'b0),
   .random(random)
);

always #5 clk = ~clk;

initial begin
   $monitor("%4d %4b %4b %4b %2b", $time, prng_dut.state, prng_dut.g_shift[0].new_state, prng_dut.g_shift[1].new_state, random);
   clk <= 0;
   rst_n <= 0;
   #10 rst_n <= 1;
   #100 $stop;
end

endmodule

`default_nettype wire

