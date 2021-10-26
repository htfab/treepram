// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Wrapper for prng with known good polynomials (having a cycle length of 2^32-1 and a minimal bit count)

Different choices of 0 <= INDEX < 256 generate independent prng's. For even more, the table below should be extended.
*/

module prng_wrap #(parameter INDEX = 0, OUTPUT_BITS = 16) (
   input clk,
   input rst_n,
   input entropy,
   output [OUTPUT_BITS-1:0] random
);

localparam STATE_BITS = 32;
localparam POLY_ARRAY_LEN = 256;
localparam POLY_ARRAY = {
   32'h80000062, 32'h80000092, 32'h80000106, 32'h80000114, 32'h80000412, 32'h80000414, 32'h80000806, 32'h80000850,
   32'h8000100C, 32'h80001050, 32'h80001C00, 32'h80002021, 32'h80002204, 32'h80002810, 32'h80004050, 32'h80004201,
   32'h80008006, 32'h80008042, 32'h80008102, 32'h80008401, 32'h80008500, 32'h80009004, 32'h80010006, 32'h80010048,
   32'h80010240, 32'h80014004, 32'h80014800, 32'h80020030, 32'h80020102, 32'h80020402, 32'h80022010, 32'h80022100,
   32'h80030010, 32'h80040022, 32'h80040280, 32'h80042020, 32'h80043000, 32'h80050008, 32'h80060040, 32'h80061000,
   32'h80080012, 32'h80080120, 32'h80094000, 32'h800A0010, 32'h80100048, 32'h80100820, 32'h801C0000, 32'h80200003,
   32'h80200060, 32'h80200101, 32'h80202001, 32'h80210001, 32'h80400021, 32'h80401020, 32'h80420010, 32'h80422000,
   32'h80508000, 32'h80800012, 32'h80801002, 32'h80810004, 32'h80840001, 32'h80900002, 32'h80A01000, 32'h81000021,
   32'h81000050, 32'h810000C0, 32'h81000220, 32'h81001020, 32'h81003000, 32'h81004040, 32'h81010020, 32'h81010040,
   32'h81204000, 32'h81400001, 32'h81400008, 32'h81800040, 32'h82000014, 32'h82000024, 32'h82000044, 32'h82000048,
   32'h82000108, 32'h82000110, 32'h82000410, 32'h82004040, 32'h82010002, 32'h82021000, 32'h82040040, 32'h82040100,
   32'h82080400, 32'h82200040, 32'h82400800, 32'h82800010, 32'h83000200, 32'h84000050, 32'h840000A0, 32'h84000401,
   32'h84002100, 32'h84002800, 32'h84006000, 32'h84022000, 32'h840A0000, 32'h84100002, 32'h84100020, 32'h84400020,
   32'h85000010, 32'h85000040, 32'h85010000, 32'h85040000, 32'h85080000, 32'h86000004, 32'h86002000, 32'h88000102,
   32'h88000140, 32'h88001002, 32'h88005000, 32'h88020001, 32'h88400020, 32'h89000002, 32'h89000020, 32'h89000400,
   32'h89004000, 32'h8A000004, 32'h8C000001, 32'h90000028, 32'h90000030, 32'h90004002, 32'h90004080, 32'h90014000,
   32'h90048000, 32'h90220000, 32'h90800002, 32'h91000020, 32'h92000020, 32'h94000020, 32'h94100000, 32'h94400000,
   32'h98040000, 32'hA0000048, 32'hA0000084, 32'hA0000410, 32'hA0000480, 32'hA0004020, 32'hA0008001, 32'hA0010004,
   32'hA0040008, 32'hA0040080, 32'hA0102000, 32'hA0400008, 32'hA0402000, 32'hA0408000, 32'hA1008000, 32'hA2001000,
   32'hA3000000, 32'hA4000080, 32'hA4000800, 32'hA4100000, 32'hA4800000, 32'hB0004000, 32'hB0008000, 32'hB0080000,
   32'hB0400000, 32'hC0000005, 32'hC0000018, 32'hC0000140, 32'hC0001080, 32'hC0002008, 32'hC0004200, 32'hC0008002,
   32'hC0020200, 32'hC0100010, 32'hC0108000, 32'hC0210000, 32'hC0400200, 32'hC2000040, 32'hC2000100, 32'hC2020000,
   32'hD0000001, 32'hE0000200, 32'h80000057, 32'h8000007A, 32'h800000B9, 32'h800000BA, 32'h8000012D, 32'h8000014E,
   32'h8000016C, 32'h800001A6, 32'h8000020F, 32'h800002CC, 32'h80000349, 32'h80000370, 32'h80000392, 32'h80000398,
   32'h80000417, 32'h80000465, 32'h8000046A, 32'h80000478, 32'h800004D4, 32'h8000050B, 32'h80000526, 32'h8000054C,
   32'h800005C1, 32'h8000060D, 32'h8000060E, 32'h80000629, 32'h80000638, 32'h80000662, 32'h800006B0, 32'h80000748,
   32'h8000088D, 32'h800008E1, 32'h80000923, 32'h80000931, 32'h80000934, 32'h80000958, 32'h80000A25, 32'h80000A26,
   32'h80000A54, 32'h80000A92, 32'h80000AC4, 32'h80000B28, 32'h80000B84, 32'h80000C34, 32'h80000C43, 32'h80000CA2,
   32'h80000D22, 32'h80000D28, 32'h80000E24, 32'h8000100F, 32'h80001027, 32'h80001035, 32'h80001047, 32'h80001071,
   32'h80001078, 32'h8000108E, 32'h800010C9, 32'h80001126, 32'h80001164, 32'h80001231, 32'h8000140E, 32'h80001485,
   32'h80001491, 32'h80001560, 32'h80001614, 32'h80001624, 32'h80001684, 32'h80001702, 32'h80001813, 32'h80001851,
   32'h80001870, 32'h800018C1, 32'h80001928, 32'h80001A06, 32'h80001A12, 32'h80001C50, 32'h80001C88, 32'h80002053
};

prng #(
   .STATE_BITS(STATE_BITS),
   .POLYNOMIAL(POLY_ARRAY[(POLY_ARRAY_LEN-1-(INDEX % POLY_ARRAY_LEN))*STATE_BITS +: STATE_BITS]),
   .STATE_INIT(INDEX),
   .OUTPUT_BITS(OUTPUT_BITS)
) prng_inst (
   .clk(clk),
   .rst_n(rst_n),
   .entropy(entropy),
   .random(random)
);

endmodule

`default_nettype wire

