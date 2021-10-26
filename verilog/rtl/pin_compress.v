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

module pin_compress (
   input [`IO_PINS-1:0] data,
   input [`IO_PINS-1:0] mask,
   output [`IO_PINS-1:0] result
);

generate genvar layer;
   for (layer=0; layer<`IO_PINS; layer=layer+1) begin:comp
      wire [`IO_PINS-1:0] sd;
      if (layer == 0) begin:i_first
         assign sd = {{(`IO_PINS-1){1'b0}}, data[`IO_PINS-1] & mask[`IO_PINS-1]};
      end else begin:i_nfirst
         wire [`IO_PINS-1:0] sdp = comp[layer-1].sd;
         assign sd = mask[`IO_PINS-1-layer] ? {sdp[`IO_PINS-2:0], data[`IO_PINS-1-layer]} : sdp;
      end
   end
   assign result = comp[`IO_PINS-1].sd;
endgenerate

endmodule

`default_nettype wire

