// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module prng_wrap_tb();

parameter INDEX = 0;
parameter OUTPUT_BITS = 128;

reg clk;
reg rst_n;
wire [OUTPUT_BITS-1:0] random;

prng_wrap #(
   .INDEX(INDEX),
   .OUTPUT_BITS(OUTPUT_BITS)
) prng_wrap_dut (
   .clk(clk),
   .rst_n(rst_n),
   .entropy(1'b0),
   .random(random)
);

always #5 clk = ~clk;

initial begin
   clk <= 0;
   rst_n <= 0;
   #10 rst_n <= 1;
   $display("%8x", prng_wrap_dut.prng_inst.POLYNOMIAL);
   $display("%8x", prng_wrap_dut.prng_inst.scrambled_init);
   $monitor("%4d %128b", $time, random);
   #200 $stop;
end

endmodule

`default_nettype wire

