// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module mem_mesh_tb();

parameter CORES = 8;
parameter DEPTH = 256;
parameter DATA_WIDTH = 16;
parameter ADDR_WIDTH = 8;
parameter SPREAD_LAYERS = 3;
parameter SPREAD_WIDTH = 3;
parameter USE_IO = 1;
parameter IO_PORTS = 16;
parameter IO_FIRST = 5;

reg clk;
reg rst_n;
reg we[CORES-1:0];
reg [ADDR_WIDTH-1:0] waddr[CORES-1:0];
reg [SPREAD_WIDTH-1:0] wspread[CORES-1:0];
reg [DATA_WIDTH-1:0] wdata[CORES-1:0];
reg [ADDR_WIDTH-1:0] raddr[CORES-1:0];
wire [DATA_WIDTH-1:0] rdata[CORES-1:0];

// io directions are according to the cpu & memory, so they are
// reversed from the point of view of the testbench / external world
reg io_dir[IO_PORTS-1:0];
reg io_receiving[IO_PORTS-1:0];
wire io_sending[IO_PORTS-1:0];
reg [DATA_WIDTH-1:0] io_input[IO_PORTS-1:0];
wire [DATA_WIDTH-1:0] io_output[IO_PORTS-1:0];

wire [CORES-1:0] we_raw;
wire [CORES*ADDR_WIDTH-1:0] waddr_raw;
wire [CORES*SPREAD_WIDTH-1:0] wspread_raw;
wire [CORES*DATA_WIDTH-1:0] wdata_raw;
wire [CORES*ADDR_WIDTH-1:0] raddr_raw;
wire [CORES*DATA_WIDTH-1:0] rdata_raw;

wire [IO_PORTS-1:0] io_active_in_raw;
wire [IO_PORTS-1:0] io_active_out_raw;
wire [IO_PORTS*DATA_WIDTH-1:0] io_data_in_raw;
wire [IO_PORTS*DATA_WIDTH-1:0] io_data_out_raw;

generate genvar core;
for (core=0; core<CORES; core=core+1) begin:g_core
   assign we_raw[core] = we[core];
   assign waddr_raw[core*ADDR_WIDTH +: ADDR_WIDTH] = waddr[core];
   assign wspread_raw[core*SPREAD_WIDTH +: SPREAD_WIDTH] = wspread[core];
   assign wdata_raw[core*DATA_WIDTH +: DATA_WIDTH] = wdata[core];
   assign raddr_raw[core*ADDR_WIDTH +: ADDR_WIDTH] = raddr[core];
   assign rdata[core] = rdata_raw[core*DATA_WIDTH +: DATA_WIDTH];
end
endgenerate

generate genvar port;
for (port=0; port<IO_PORTS; port=port+1) begin:g_port
   assign io_active_in_raw[port] = io_dir[port] ? 1'b0 : io_receiving[port];
   assign io_sending[port] = io_dir[port] ? io_active_out_raw[port] : 1'b0;
   assign io_data_in_raw[port*DATA_WIDTH +: DATA_WIDTH] = io_dir[port] ? {(DATA_WIDTH){1'b0}} : io_input[port];
   assign io_output[port] = io_dir[port] ? io_data_out_raw[port*DATA_WIDTH +: DATA_WIDTH] : {(DATA_WIDTH){1'b0}};
end
endgenerate

mem_mesh #(
   .CORES(CORES),
   .DEPTH(DEPTH),
   .DATA_WIDTH(DATA_WIDTH),
   .ADDR_WIDTH(ADDR_WIDTH),
   .SPREAD_LAYERS(SPREAD_LAYERS),
   .SPREAD_WIDTH(SPREAD_WIDTH),
   .USE_IO(USE_IO),
   .IO_PORTS(IO_PORTS),
   .IO_FIRST(IO_FIRST)
) mem_mesh_dut (
   .clk(clk),
   .rst_n(rst_n),
   .we(we_raw),
   .waddr(waddr_raw),
   .wspread(wspread_raw),
   .wdata(wdata_raw),
   .raddr(raddr_raw),
   .rdata(rdata_raw),
   .io_active_in(io_active_in_raw),
   .io_active_out(io_active_out_raw),
   .io_data_in(io_data_in_raw),
   .io_data_out(io_data_out_raw)
);

always #5 clk = ~clk;

integer i;

// for synchronization checking
reg io_sending_reg[IO_PORTS-1:0];
reg [DATA_WIDTH-1:0] io_output_reg[IO_PORTS-1:0];

always @(posedge clk) begin
   for (i=0; i<IO_PORTS; i=i+1) begin
      io_sending_reg[i] <= io_sending[i];
      io_output_reg[i] <= io_output[i];
   end
end

initial begin
   raddr[2] = 8;
   raddr[3] = 8;
   raddr[6] = 8;
   raddr[7] = 192;
   wspread[2] = 0;
   io_input[3] = 0;
   $monitor("time=%t mem[2][8]=%d mem[3][8]=%d mem[6][8]=%d mem[7][192]=%d io_dir[3]=%d io_sending[3]=%d io_out[3]=%d",
               $time, rdata[2], rdata[3], rdata[6], rdata[7], io_dir[3], io_sending_reg[3], io_output_reg[3]);

   for (i=0; i<CORES; i=i+1) begin
      we[i] = 0;
   end

   for (i=0; i<IO_PORTS; i=i+1) begin
      io_dir[i] = 1;
   end

   clk = 0;
   rst_n = 1;
   #10 rst_n = 0;
   #10 rst_n = 1;

   #20
   we[2] = 1;
   waddr[2] = 8;
   wspread[2] = 0;
   wdata[2] = 100;

   #20
   waddr[2] = 8;
   wspread[2] = 1;
   wdata[2] = 200;

   #20
   waddr[2] = 8;
   wspread[2] = 2;
   wdata[2] = 300;

   #20
   waddr[2] = 8;
   wspread[2] = 3;
   wdata[2] = 400;

   #20
   waddr[2] = 8;
   wspread[2] = 4;
   wdata[2] = 500;

   #20
   io_dir[3] = 0;
   io_receiving[3] = 0;

   #20
   io_receiving[3] = 1;
   io_input[3] = 1234;

   #20 $stop;
end

endmodule

`default_nettype wire

