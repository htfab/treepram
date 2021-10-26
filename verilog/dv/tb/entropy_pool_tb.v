// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module entropy_pool_tb();

parameter WIDTH = 16;

reg clk;
reg rst_n;
reg [WIDTH-1:0] e_word;
wire e_bit;

entropy_pool #(
   .WIDTH(WIDTH)
) entropy_pool_dut (
   .clk(clk),
   .rst_n(rst_n),
   .e_word(e_word),
   .e_bit(e_bit)
);

always #5 clk = ~clk;

reg strobe;
always @(posedge clk) strobe = ~strobe;   // force a $monitor strobe every clock cycle

initial begin
   $monitor("time %4t s %1b ew %16b es %15b eb %1b", $time, strobe, e_word, entropy_pool_dut.e_pool_mod, e_bit);
   clk = 0;
   rst_n = 0;
   strobe = 0;
   #10
   rst_n = 1;
   e_word = 16'b0111110000111001;
   #10
   e_word = 0;
   #100
   e_word = 16'b1010101010101010;
   #10
   e_word = 0;
   #200
   $stop;
end

endmodule

`default_nettype wire

