// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module alu_tb();

parameter DATA_WIDTH = 16;

reg [3:0] opcode;
reg [DATA_WIDTH-1:0] in1;
reg [DATA_WIDTH-1:0] in2;
reg carry;
wire [DATA_WIDTH-1:0] out;
wire carry_out;

alu #(
   .DATA_WIDTH(DATA_WIDTH)
) alu_dut (
   .opcode(opcode),
   .in1(in1),
   .in2(in2),
   .carry(carry),
   .out(out),
   .carry_out(carry_out)
);

integer i;

initial begin
   $monitor("time=%4t op=%4b in1=%16b in2=%16b carry=%1b out=%16b carry_out=%1b", $time, opcode, in1, in2, carry, out, carry_out);

   in1 = 16'b0011001100110011;
   //in2 = 16'b0000111100001111;
   in2 = 16'b101;
   for (i=0; i<16; i=i+1) begin
      #10 opcode=i;
          carry = 0;
      #10 carry = 1;
   end

   opcode = 15;
   in2 = 0;
   carry = 1;
   for (i=0; i<18; i=i+1) begin
       in1 = i;
       #10;
   end
   for (i=17; i>=0; i=i-1) begin
       in1 = ~i & {1'b0, {(15){1'b1}}};
       #10;
   end
   for (i=0; i<18; i=i+1) begin
       in1 = i | {1'b1, {(15){1'b0}}};
       #10;
   end
   for (i=17; i>=0; i=i-1) begin
       in1 = ~i;
       #10;
   end

   #10 $stop;
end

endmodule

`default_nettype wire

