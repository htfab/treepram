// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module pin_decompress_tb ();

parameter WIDTH = 16;

reg [WIDTH-1:0] data;
reg [WIDTH-1:0] mask;
wire [WIDTH-1:0] result;

pin_decompress #(
   .WIDTH(WIDTH)
) pin_decompress_dut (
   .data(data),
   .mask(mask),
   .result(result)
);

initial begin
   data <= 16'b0000000000001011;
   mask <= 16'b0101000101000101;
   #10
   $display("%16b", result);
   $display("%16b", 16'b0000000100000101);
end

endmodule

`default_nettype wire

