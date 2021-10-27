// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Generates a DFF RAM block for each core with a tree-like interconnect mesh between them

A value of wspread > 0 on write operations specifies that the same address should also be written in some
other memory blocks. In particular, blocks whose number only differ in the lowest wspread bits are affected.
If several simultaneous write operations affect the same memory cell, writes with higher wspread have
priority. For writes having equal wspread the core with the lowest number wins.

If addresses >= `MEM_IO_FIRST are written with wspread > `LOG_CORES, wdata is also sent to the io bus.
Incoming data on the io bus is written to the respective cells with maximal spread (affecting all cores).
*/

module mem_mesh (
   input clk,                                         // clock signal
   input rst_n,                                       // reset, active low
   input [`CORES-1:0] we,                             // write enable
   input [`CORES*`ADDR_WIDTH-1:0] waddr,              // write address
   input [`CORES*`SPREAD_WIDTH-1:0] wspread,          // write spread
   input [`CORES*`DATA_WIDTH-1:0] wdata,              // write data
   input [`CORES*`ADDR_WIDTH-1:0] raddr,              // read address
   output [`CORES*`DATA_WIDTH-1:0] rdata,             // read data
   input [`MEM_IO_PORTS-1:0] io_active_in,            // is receiving data on io bus
   output [`MEM_IO_PORTS-1:0] io_active_out,          // is sending data on io bus
   input [`MEM_IO_PORTS*`DATA_WIDTH-1:0] io_data_in,  // io bus input
   output [`MEM_IO_PORTS*`DATA_WIDTH-1:0] io_data_out // io bus output
);

reg [`DATA_WIDTH-1:0] mem[`CORES-1:0][`MEM_DEPTH-1:0];       // memory cells
wire presel[`CORES-1:0][`MEM_DEPTH-1:0];                     // is address selected before spreading
wire uspread[`CORES-1:0][`LOG_CORES+1-1:0];                  // is spreading to layer
wire postsel[`CORES-1:0][`MEM_DEPTH-1:0];                    // is address selected after spreading
wire [`DATA_WIDTH-1:0] postdata[`CORES-1:0][`MEM_DEPTH-1:0]; // data to be written after spreading

generate genvar core, addr, layer, group, spl;

// convert spread to unary
for (core=0; core<`CORES; core=core+1) begin:g_core
   for(layer=0; layer<=`LOG_CORES; layer=layer+1) begin:g_layer
      assign uspread[core][layer] = we[core] & wspread[core*`SPREAD_WIDTH +: `SPREAD_WIDTH] > layer;
   end
end

for (addr=0; addr<`MEM_DEPTH; addr=addr+1) begin:g_cell

   // convert write address to one-hot encoding
   for (core=0; core<`CORES; core=core+1) begin:g_core_m
      assign presel[core][addr] = we[core] & (waddr[core*`ADDR_WIDTH +: `ADDR_WIDTH] == addr);
   end

   // calculate spreading from individual cores to groups of cores
   for (layer=0; layer<=`LOG_CORES; layer=layer+1) begin:spread
      localparam GROUPS = `CORES >> layer;
      wire gsel[GROUPS-1:0];
      wire [`DATA_WIDTH-1:0] gdata[GROUPS-1:0];
      wire gspread[GROUPS-1:0][`LOG_CORES+1-layer-1:0];
      if (layer == 0) begin:i_layerz
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            assign gsel[group] = presel[group][addr];
            assign gdata[group] = {(`DATA_WIDTH){we[group]}} & wdata[group*`DATA_WIDTH +: `DATA_WIDTH];
            for (spl=0; spl<=`LOG_CORES; spl=spl+1) begin:cspread
               assign g_cell[addr].spread[layer].gspread[group][spl] = uspread[group][spl];
            end
         end
      end else begin:i_layernz
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            wire gs1 = g_cell[addr].spread[layer-1].gsel[group*2] & g_cell[addr].spread[layer-1].gspread[group*2][0];
            wire gs2 = g_cell[addr].spread[layer-1].gsel[group*2+1] & g_cell[addr].spread[layer-1].gspread[group*2+1][0];
            wire [`DATA_WIDTH-1:0] gd1 = g_cell[addr].spread[layer-1].gdata[group*2];
            wire [`DATA_WIDTH-1:0] gd2 = g_cell[addr].spread[layer-1].gdata[group*2+1];
            assign gsel[group] = gs1 | gs2;
            assign gdata[group] = gs1 ? gd1 : gd2;
            for (spl=0; spl<=`LOG_CORES-layer; spl=spl+1) begin:g_spread
               wire gsp1 = g_cell[addr].spread[layer-1].gspread[group*2][spl+1];
               wire gsp2 = g_cell[addr].spread[layer-1].gspread[group*2+1][spl+1];
               assign g_cell[addr].spread[layer].gspread[group][spl] = gs1 ? gsp1 : gsp2;
            end
         end
      end
   end

   // mix in io logic at the highest spreading level
   wire gs_i;
   wire [`DATA_WIDTH-1:0] gd_i;
   if (`MEM_IO_FIRST <= addr && addr < `MEM_IO_LAST1) begin:i_io
      localparam io = addr - `MEM_IO_FIRST;
      wire gs_o = g_cell[addr].spread[`LOG_CORES].gsel[0] & g_cell[addr].spread[`LOG_CORES].gspread[0][0];
      wire [`DATA_WIDTH-1:0] gd_o = {(`DATA_WIDTH){gs_o}} & g_cell[addr].spread[`LOG_CORES].gdata[0];
      assign io_active_out[io] = gs_o;
      assign io_data_out[io*`DATA_WIDTH +: `DATA_WIDTH] = gd_o;
      assign gs_i = io_active_in[io] ? 1'b1 : g_cell[addr].spread[`LOG_CORES].gsel[0];
      assign gd_i = io_active_in[io] ? io_data_in[io*`DATA_WIDTH +: `DATA_WIDTH] : g_cell[addr].spread[`LOG_CORES].gdata[0];
   end else begin:i_nio
      assign gs_i = g_cell[addr].spread[`LOG_CORES].gsel[0];
      assign gd_i = g_cell[addr].spread[`LOG_CORES].gdata[0];
   end

   // calculate spreading back from groups of cores to individual cores
   for (layer=`LOG_CORES; layer>=0; layer=layer-1) begin:collect
      localparam GROUPS = `CORES >> layer;
      wire pgsel[GROUPS-1:0];
      wire [`DATA_WIDTH-1:0] pgdata[GROUPS-1:0];
      if (layer == `LOG_CORES) begin:i_layerl
         assign pgsel[0] = gs_i;
         assign pgdata[0] = gd_i;
         for (group=1; group<GROUPS; group=group+1) begin:g_group
            assign pgsel[group] = g_cell[addr].spread[layer].gsel[group];
            assign pgdata[group] = g_cell[addr].spread[layer].gdata[group];
         end
      end else begin:i_layernl
         for (group=0; group<GROUPS; group=group+1) begin:g_group
            wire gs = g_cell[addr].spread[layer].gsel[group];
            wire [`DATA_WIDTH-1:0] gd = g_cell[addr].spread[layer].gdata[group];
            wire cgs = g_cell[addr].collect[layer+1].pgsel[group/2];
            wire [`DATA_WIDTH-1:0] cgd = g_cell[addr].collect[layer+1].pgdata[group/2];
            assign pgsel[group] = cgs | gs;
            assign pgdata[group] = cgs ? cgd : gd;
         end
      end
   end
   for (core=0; core<`CORES; core=core+1) begin:g_core_c
      assign postsel[core][addr] = g_cell[addr].collect[0].pgsel[core];
      assign postdata[core][addr] = g_cell[addr].collect[0].pgdata[core];
   end

   // sequential write logic
   for (core=0; core<`CORES; core=core+1) begin:g_core_w
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
for (core=0; core<`CORES; core=core+1) begin:g_core_r
   wire [`ADDR_WIDTH-1:0] craddr = raddr[core*`ADDR_WIDTH +: `ADDR_WIDTH];
   assign rdata[core*`DATA_WIDTH +: `DATA_WIDTH] = mem[core][craddr];
end

endgenerate

endmodule

`default_nettype wire

