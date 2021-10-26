// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Fully combinatorial circuit shifting input bits to the mask bit positions

E.g.
data   = 0000000000001011
mask   = 0101000101000101
          0 0   1 0   1 1
result = 0000000100000101
*/

module pin_decompress (
   input [`IO_PINS-1:0] data,
   input [`IO_PINS-1:0] mask,
   output [`IO_PINS-1:0] result
);

generate genvar layer;
   for (layer=0; layer<`IO_PINS; layer=layer+1) begin:decomp
      wire [`IO_PINS-1:0] sd;
      if (layer == 0) begin:i_first
         assign sd = data;
      end else begin:i_nfirst
         wire [`IO_PINS-1:0] sdp = decomp[layer-1].sd;
         assign sd = mask[layer-1] ? sdp >> 1 : sdp;
      end
      assign result[layer] = mask[layer] & sd[0];
   end
endgenerate

endmodule

`default_nettype wire

