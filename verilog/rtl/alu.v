// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Fully combinatorial arithmetic logic unit

Opcode matrix:
0000  and   in1 & in2               out set to result, carry_out set to |result
0001  or    in1 | in2               out set to result, carry_out set to &result
0010  xor   in1 ^ in2               out set to result, carry_out set to ^result
0011  mux   carry ? in2 : in1       out set to result, carry_out set to highest bit of result
0100  nand  ~(in1 & in2)            out set to result, carry_out set to &result
0101  nor   ~(in1 | in2)            out set to result, carry_out set to |result
0110  nxor  ~(in1 ^ in2)            out set to result, carry_out set to ~^~result
0111  nmux  ~(carry ? in2 : in1)    out set to result, carry_out set to highest bit of result
1000  rcl   in1 << in2              carry shifted in, carry_out shifted out
1001  rcr   in1 >> in2              carry shifted in, carry_out shifted out
1010  add   in1 + in2 + carry       {carry_out, out} set to result
1011  sub   in1 - in2 - carry       {carry_out, out} set to result
1100  mul   in1 * in2               out set to low W bits of result, carry_out set if high W bits are nonzero
1101  mulh  in1 * in2               out set to high W bits of result, carry_out set if high W bits are nonzero
1110  muld  in1 * {1, in2}          {carry_out, out} set to high W+1 bits of result
1111  log   clog2(in1 + carry)      out set to result, carry_out set if in1 + carry is a power of 2

There is no division opcode, but `muld` was included for the "division by invariant multiplication" algorithm.
Division by a constant can be compiled to a `muld` followed by an `rcr`.
*/

module alu (
   input [3:0] opcode,
   input [`DATA_WIDTH-1:0] in1,
   input [`DATA_WIDTH-1:0] in2,
   input carry,
   output [`DATA_WIDTH-1:0] out,
   output carry_out
);

   wire [`DATA_WIDTH-1:0] op_out[15:0];
   wire op_carry[15:0];

   wire [`DATA_WIDTH-1:0] and_out = in1 & in2;
   wire and_carry = |and_out;
   assign op_out[0] = and_out;
   assign op_carry[0] = and_carry;

   wire [`DATA_WIDTH-1:0] or_out = in1 | in2;
   wire or_carry = &or_out;
   assign op_out[1] = or_out;
   assign op_carry[1] = or_carry;

   wire [`DATA_WIDTH-1:0] xor_out = in1 ^ in2;
   wire xor_carry = ^xor_out;
   assign op_out[2] = xor_out;
   assign op_carry[2] = xor_carry;

   wire [`DATA_WIDTH-1:0] mux_out = carry ? in2 : in1;
   wire mux_carry = mux_out[`DATA_WIDTH-1];
   assign op_out[3] = mux_out;
   assign op_carry[3] = mux_carry;

   wire [`DATA_WIDTH-1:0] nand_out = ~and_out;
   wire nand_carry = ~and_carry;
   assign op_out[4] = nand_out;
   assign op_carry[4] = nand_carry;

   wire [`DATA_WIDTH-1:0] nor_out = ~or_out;
   wire nor_carry = ~or_carry;
   assign op_out[5] = nor_out;
   assign op_carry[5] = nor_carry;

   wire [`DATA_WIDTH-1:0] nxor_out = ~xor_out;
   wire nxor_carry = ~xor_carry;
   assign op_out[6] = nxor_out;
   assign op_carry[6] = nxor_carry;

   wire [`DATA_WIDTH-1:0] nmux_out = ~mux_out;
   wire nmux_carry = ~mux_carry;
   assign op_out[7] = nmux_out;
   assign op_carry[7] = nmux_carry;

   wire [`DATA_WIDTH-1:0] rcl_out;
   wire rcl_carry, rcl_ignore;
   assign {rcl_carry, rcl_out, rcl_ignore} = {1'b0, in1, carry} << in2;
   assign op_out[8] = rcl_out;
   assign op_carry[8] = rcl_carry;

   wire [`DATA_WIDTH-1:0] rcr_out;
   wire rcr_carry, rcr_ignore;
   assign {rcr_ignore, rcr_out, rcr_carry} = {carry, in1, 1'b0} >> in2;
   assign op_out[9] = rcr_out;
   assign op_carry[9] = rcr_carry;

   wire [`DATA_WIDTH-1:0] add_out;
   wire add_carry;
   assign {add_carry, add_out} = in1 + in2 + carry;
   assign op_out[10] = add_out;
   assign op_carry[10] = add_carry;

   wire [`DATA_WIDTH-1:0] sub_out;
   wire sub_carry;
   assign {sub_carry, sub_out} = in1 - in2 - carry;
   assign op_out[11] = sub_out;
   assign op_carry[11] = sub_carry;

   wire [`DATA_WIDTH-1:0] mulh_out;
   wire [`DATA_WIDTH-1:0] mul_out;
   assign {mulh_out, mul_out} = in1 * in2;
   wire mul_carry = |mulh_out;
   wire mulh_carry = mul_carry;
   assign op_out[12] = mul_out;
   assign op_carry[12] = mul_carry;
   assign op_out[13] = mulh_out;
   assign op_carry[13] = mulh_carry;

   wire [`DATA_WIDTH-1:0] muld_out;
   wire [`DATA_WIDTH-1:0] muld_ignore;
   wire muld_carry;
   assign {muld_carry, muld_out, muld_ignore} = in1 * {1'b1, in2};
   assign op_out[14] = muld_out;
   assign op_carry[14] = muld_carry;

   wire [`DATA_WIDTH-1:0] in1c = in1 + carry;
   wire [`DATA_WIDTH-1:0] in1d = in1 - (!carry);
   wire [`DATA_WIDTH-1:0] log_bits;
   localparam LOG_WIDTH = $clog2(`DATA_WIDTH);
   assign log_bits[`DATA_WIDTH-1:LOG_WIDTH] = 0;
   generate genvar i;
   for (i=LOG_WIDTH-1; i>=0; i=i-1) begin:g_bit
      wire [(1<<(i+1))-1:0] subseq;
      if (i == LOG_WIDTH-1) begin:i_first
         assign subseq = in1d;
      end else begin:i_nfirst
         wire [i+1:0] index = {log_bits[i+1], {(i+1){1'b0}}};
         assign subseq = g_bit[i+1].subseq >> index;
      end
      assign log_bits[i] = |subseq[1<<i +: 1<<i];
   end
   endgenerate
   wire in1nz = in1c || carry;
   wire in1no = |in1d;
   wire [`DATA_WIDTH-1:0] log_out = in1nz ? (log_bits + in1no) : -1;
   wire log_carry = in1nz && !(in1c & in1d);
   assign op_out[15] = log_out;
   assign op_carry[15] = log_carry;

   assign out = op_out[opcode];
   assign carry_out = op_carry[opcode];

endmodule

`default_nettype wire

