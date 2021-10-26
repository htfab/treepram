// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module pin_compress_tb ();

parameter WIDTH = 16;

reg [WIDTH-1:0] data;
reg [WIDTH-1:0] mask;
wire [WIDTH-1:0] result;

pin_compress #(
   .WIDTH(WIDTH)
) pin_compress_dut (
   .data(data),
   .mask(mask),
   .result(result)
);

initial begin
   data <= 16'b1001110100110101;
   mask <= 16'b0100100101000101;
   #10
   $display("%16b", result);
   $display("%16b", 16'b0000000000011011);
end

endmodule

`default_nettype wire

