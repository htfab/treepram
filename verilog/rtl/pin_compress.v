// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Fully combinatorial circuit shifting input bits from the mask bit positions

E.g.
data   = 1001110100110101
mask   = 0100100101000101
          0  1  1 0   1 1
result = 0000000000011011
*/

module pin_compress #(parameter WIDTH=16) (
   input [WIDTH-1:0] data,
   input [WIDTH-1:0] mask,
   output [WIDTH-1:0] result
);

generate genvar layer;
   for (layer=0; layer<WIDTH; layer=layer+1) begin:comp
      wire [WIDTH-1:0] sd;
      if (layer == 0) begin:i_first
         assign sd = {{(WIDTH-1){1'b0}}, data[WIDTH-1] & mask[WIDTH-1]};
      end else begin:i_nfirst
         wire [WIDTH-1:0] sdp = comp[layer-1].sd;
         assign sd = mask[WIDTH-1-layer] ? {sdp[WIDTH-2:0], data[WIDTH-1-layer]} : sdp;
      end
   end
   assign result = comp[WIDTH-1].sd;
endgenerate

endmodule

`default_nettype wire

