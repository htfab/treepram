// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Generates a DFF RAM block for each core with a tree-like interconnect mesh between them

Parameters:
CORES = number of cpu cores, also specifies the number of ram blocks
DEPTH = number of words per ram block
DATA_WIDTH = word size, number of bits per memory cell
ADDR_WIDTH = address bus width, should be clog2(DEPTH)
SPREAD_LAYERS = number of spread layers, should be clog2(CORES)
SPREAD_WIDTH = spread bus width, should be clog2(2+SPREAD_LAYERS)
IO_PORTS = number of io ports, should be <= DEPTH
IO_FIRST = memory cell mapped to the first io port, should be <= DEPTH - IO_PORTS

A value of wspread > 0 on write operations specifies that the same address should also be written in some
other memory blocks. In particular, blocks whose number only differ in the lowest wspread bits are affected.
If several simultaneous write operations affect the same memory cell, writes with higher wspread have
priority. For writes having equal wspread the core with the lowest number wins.

If addresses < IO_BUS_WIDTH are written with wspread > SPREAD_LAYERS, wdata is also sent to the io bus.
Incoming data on the io bus is written to the respective cells with maximal spread (affecting all cores).
*/

module mem_mesh #(parameter CORES=8, DEPTH=256, DATA_WIDTH=16, ADDR_WIDTH=8, SPREAD_LAYERS=3, SPREAD_WIDTH=3, USE_IO=1, IO_PORTS=16, IO_FIRST=240) (
   input clk,                                   // clock signal
   input rst_n,                                 // reset, active low
   input [CORES-1:0] we,                        // write enable
   input [CORES*ADDR_WIDTH-1:0] waddr,          // write address
   input [CORES*SPREAD_WIDTH-1:0] wspread,      // write spread
   input [CORES*DATA_WIDTH-1:0] wdata,          // write data
   input [CORES*ADDR_WIDTH-1:0] raddr,          // read address
   output [CORES*DATA_WIDTH-1:0] rdata,         // read data
   input [IO_PORTS-1:0] io_active_in,           // is receiving data on io bus
   output [IO_PORTS-1:0] io_active_out,         // is sending data on io bus
   input [IO_PORTS*DATA_WIDTH-1:0] io_data_in,  // io bus input
   output [IO_PORTS*DATA_WIDTH-1:0] io_data_out // io bus output
);

reg [DATA_WIDTH-1:0] mem[CORES-1:0][DEPTH-1:0];       // memory cells
wire presel[CORES-1:0][DEPTH-1:0];                    // is address selected before spreading
wire uspread[CORES-1:0][SPREAD_LAYERS+1-1:0];         // is spreading to layer
wire postsel[CORES-1:0][DEPTH-1:0];                   // is address selected after spreading
wire [DATA_WIDTH-1:0] postdata[CORES-1:0][DEPTH-1:0]; // data to be written after spreading

generate genvar core, addr, layer, group, spl;

// convert spread to unary
for (core=0; core<CORES; core=core+1) begin:g_core
   for(layer=0; layer<=SPREAD_LAYERS; layer=layer+1) begin:g_layer
      assign uspread[core][layer] = we[core] & wspread[core*SPREAD_WIDTH +: SPREAD_WIDTH] > layer;
   end
end

for (addr=0; addr<DEPTH; addr=addr+1) begin:g_cell

   // convert write address to one-hot encoding
   for (core=0; core<CORES; core=core+1) begin:g_core_m
      assign presel[core][addr] = we[core] & (waddr[core*ADDR_WIDTH +: ADDR_WIDTH] == addr);
   end

   // calculate spreading from individual cores to groups of cores
   for (layer=0; layer<=SPREAD_LAYERS; layer=layer+1) begin:spread
      localparam GROUPS = CORES >> layer;
      wire gsel[GROUPS-1:0];
      wire [DATA_WIDTH-1:0] gdata[GROUPS-1:0];
      wire gspread[GROUPS-1:0][SPREAD_LAYERS+1-layer-1:0];
      if (layer == 0) begin:i_layerz
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            assign gsel[group] = presel[group][addr];
            assign gdata[group] = {(DATA_WIDTH){we[group]}} & wdata[group*DATA_WIDTH +: DATA_WIDTH];
            for (spl=0; spl<=SPREAD_LAYERS; spl=spl+1) begin:cspread
               assign gspread[group][spl] = uspread[group][spl];
            end
         end
      end else begin:i_layernz
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            wire gs1 = spread[layer-1].gsel[group*2] & spread[layer-1].gspread[group*2][0];
            wire gs2 = spread[layer-1].gsel[group*2+1] & spread[layer-1].gspread[group*2+1][0];
            wire [DATA_WIDTH-1:0] gd1 = spread[layer-1].gdata[group*2];
            wire [DATA_WIDTH-1:0] gd2 = spread[layer-1].gdata[group*2+1];
            assign gsel[group] = gs1 | gs2;
            assign gdata[group] = gs1 ? gd1 : gd2;
            for (spl=0; spl<=SPREAD_LAYERS-layer; spl=spl+1) begin:g_spread
               wire gsp1 = spread[layer-1].gspread[group*2][spl+1];
               wire gsp2 = spread[layer-1].gspread[group*2+1][spl+1];
               assign gspread[group][spl] = gs1 ? gsp1 : gsp2;
            end
         end
      end
   end

   // mix in io logic at the highest spreading level
   wire gs_i;
   wire [DATA_WIDTH-1:0] gd_i;
   if (USE_IO && IO_FIRST <= addr && addr < IO_FIRST + IO_PORTS) begin:i_io
      localparam io = addr - IO_FIRST;
      wire gs_o = spread[SPREAD_LAYERS].gsel[0] & spread[SPREAD_LAYERS].gspread[0][0];
      wire [DATA_WIDTH-1:0] gd_o = {(DATA_WIDTH){gs_o}} & spread[SPREAD_LAYERS].gdata[0];
      assign io_active_out[io] = gs_o;
      assign io_data_out[io*DATA_WIDTH +: DATA_WIDTH] = gd_o;
      assign gs_i = io_active_in[io] ? 1'b1 : spread[SPREAD_LAYERS].gsel[0];
      assign gd_i = io_active_in[io] ? io_data_in[io*DATA_WIDTH +: DATA_WIDTH] : spread[SPREAD_LAYERS].gdata[0];
   end else begin:i_nio
      assign gs_i = spread[SPREAD_LAYERS].gsel[0];
      assign gd_i = spread[SPREAD_LAYERS].gdata[0];
   end

   // calculate spreading back from groups of cores to individual cores
   for (layer=SPREAD_LAYERS; layer>=0; layer=layer-1) begin:collect
      localparam GROUPS = CORES >> layer;
      wire pgsel[GROUPS-1:0];
      wire [DATA_WIDTH-1:0] pgdata[GROUPS-1:0];
      if (layer == SPREAD_LAYERS) begin:i_layerl
         assign pgsel[0] = gs_i;
         assign pgdata[0] = gd_i;
         for (group=1; group<GROUPS; group=group+1) begin:g_group
            assign pgsel[group] = spread[layer].gsel[group];
            assign pgdata[group] = spread[layer].gdata[group];
         end
      end else begin:i_layernl
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            wire gs = spread[layer].gsel[group];
            wire [DATA_WIDTH-1:0] gd = spread[layer].gdata[group];
            wire cgs = collect[layer+1].pgsel[group/2];
            wire [DATA_WIDTH-1:0] cgd = collect[layer+1].pgdata[group/2];
            assign pgsel[group] = cgs | gs;
            assign pgdata[group] = cgs ? cgd : gd;
         end
      end
   end
   for (core=0; core<CORES; core=core+1) begin:g_core_c
      assign postsel[core][addr] = collect[0].pgsel[core];
      assign postdata[core][addr] = collect[0].pgdata[core];
   end

   // sequential write logic
   for (core=0; core<CORES; core=core+1) begin:g_core_w
      always @(posedge clk) begin
         if (!rst_n) begin
            mem[core][addr] <= 0;
         end else begin
            if (postsel[core][addr]) begin
               mem[core][addr] <= postdata[core][addr];
            end
         end
      end
   end

end

// read logic
for (core=0; core<CORES; core=core+1) begin:g_core_r
   wire [ADDR_WIDTH-1:0] craddr = raddr[core*ADDR_WIDTH +: ADDR_WIDTH];
   assign rdata[core*DATA_WIDTH +: DATA_WIDTH] = mem[core][craddr];
end

endgenerate

endmodule

`default_nettype wire

