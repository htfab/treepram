// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Microcontroller unit

Combines the cpu cores with their corresponding instruction memories and prng's,
the memory mesh, io filter and programming multiplexer into a single package

       ||||||                                              |||   |||
  +--------------+                                       +-----------+
  |              |=======================================| pads & la |
  |              |                   +--------------+    +-----------+
  |    wb mux    |===================| entropy pool |=+       |||
  |              |   +-----------+   +--------------+ |  +-----------+
  |              |===| debug mux |                    |  | io filter |
  +--------------+   +-----------+           +------+ |  +-----------+
    ||||                  ||| +----------+ +=| prng |=+       |||
  +------+  +-----------+ ||+=| cpu core |=+ +------+ |  +-----------+
  |      |==| instr mem |=====|   w/alu  |===============|           |
  |      |  |           | ||  +----------+   +------+ |  |           |
  |      |  | - - - - - | ||  +----------+ +=| prng |=+  |           |
  | prog |  |           | |+==| cpu core |=+ +------+ |  |           |
  |  mux |==| instr mem |=====|   w/alu  |===============| mem mesh  |
  |      |  |           | |   +----------+   +------+ |  |           |
  |      |  | - - - - - | |   +----------+ +=| prng |=+  |           |
  |      |  |           | +===| cpu core |=+ +------+    |           |
  |      |==| instr mem |=====|   w/alu  |===============|           |
  +------+  +-----------+     +----------+               +-----------+

*/

module mcu (
   input wb_clk_i,                         // wishbone clock
   input wb_rst_i,                         // wb reset, active high
   input wbs_stb_i,                        // wb strobe
   input wbs_cyc_i,                        // wb cycle
   input wbs_we_i,                         // wb write enable
   input [`WB_WIDTH-1:0] wbs_adr_i,        // wb address
   input [`WB_WIDTH-1:0] wbs_dat_i,        // wb input data
   output wbs_ack_o,                       // wb acknowledge
   output [`WB_WIDTH-1:0] wbs_dat_o,       // wb output data
   input [`LOGIC_PROBES-1:0] la_data_in,   // logic analyzer probes input
   output [`LOGIC_PROBES-1:0] la_data_out, // la probes output
   input [`LOGIC_PROBES-1:0] la_oenb,      // la probes direction, 0=input (write by la), 1=output (read by la)
   input [`IO_PADS-1:0] io_in,             // io pads input
   output [`IO_PADS-1:0] io_out,           // io pads output
   output [`IO_PADS-1:0] io_oeb            // io pads direction, 0=output (write by mcu), 1=input (read by mcu)
);

localparam SPREAD_LAYERS = `LOG_CORES;
localparam SPREAD_WIDTH = $clog2(2 + SPREAD_LAYERS);
localparam MEM_IO_PORTS = 2 + `IO_PINS;
localparam MEM_IO_FIRST = `MEM_DEPTH - MEM_IO_PORTS;

// clock and reset signals, set by io_pads using wb_clk_i, wb_rst_i and logic probes
wire clk;
wire rst_hard_n;
wire rst_soft_n;
wire rst_prng_n;

// between io pads and io filter
wire [`IO_PINS-1:0] pin_dir;                           // pads > iof
wire [`IO_PINS-1:0] pin_data_in;                       // pads > iof
wire [`IO_PINS-1:0] pin_data_out;                      // pads < iof

// between cpu core and instruction memory (unpacked version for cpu core)
wire [`PC_WIDTH-1:0] im_raddr[`CORES-1:0];             // cpu > im
wire [`INSTR_WIDTH-1:0] im_rdata[`CORES-1:0];          // cpu < im

// between cpu core and instruction memory (packed version for instruction memory)
wire [`CORES*`PC_WIDTH-1:0] im_raddr_raw;              // cpu > im
wire [`CORES*`INSTR_WIDTH-1:0] im_rdata_raw;           // cpu < im

// between cpu core and memory mesh (unpacked versions for cpu cores)
wire [`DATA_WIDTH-1:0] mem_rdata[`CORES-1:0];          // cpu < mesh
wire mem_we[`CORES-1:0];                               // cpu > mesh
wire [`ADDR_WIDTH-1:0] mem_waddr[`CORES-1:0];          // cpu > mesh
wire [SPREAD_WIDTH-1:0] mem_wspread[`CORES-1:0];       // cpu > mesh
wire [`DATA_WIDTH-1:0] mem_wdata[`CORES-1:0];          // cpu > mesh
wire [`ADDR_WIDTH-1:0] mem_raddr[`CORES-1:0];          // cpu > mesh

// between cpu core and memory mesh (packed versions for memory mesh)
wire [`CORES*`DATA_WIDTH-1:0] mem_rdata_raw;           // cpu < mesh
wire [`CORES-1:0] mem_we_raw;                          // cpu > mesh
wire [`CORES*`ADDR_WIDTH-1:0] mem_waddr_raw;           // cpu > mesh
wire [`CORES*SPREAD_WIDTH-1:0] mem_wspread_raw;        // cpu > mesh
wire [`CORES*`DATA_WIDTH-1:0] mem_wdata_raw;           // cpu > mesh
wire [`CORES*`ADDR_WIDTH-1:0] mem_raddr_raw;           // cpu > mesh

// between cpu core and corresponding prng
wire [`DATA_WIDTH-1:0] prng_random[`CORES-1:0];        // cpu < prng

// between instruction memory and programming multiplexer
wire [`CORES-1:0] im_we_raw;                           // im < pmux
wire [`CORES*`PC_WIDTH-1:0] im_waddr_raw;              // im < pmux
wire [`CORES*`INSTR_WIDTH-1:0] im_wdata_raw;           // im < pmux

// between memory mesh and io filter
wire [MEM_IO_PORTS-1:0] mem_io_active_in;              // mesh < iof
wire [MEM_IO_PORTS-1:0] mem_io_active_out;             // mesh > iof
wire [MEM_IO_PORTS*`DATA_WIDTH-1:0] mem_io_data_in;    // mesh < iof
wire [MEM_IO_PORTS*`DATA_WIDTH-1:0] mem_io_data_out;   // mesh > iof

// between debugging multiplexer and cpu core (unpacked versions for cpu core)
wire [1:0] debug_cpu_mode[`CORES-1:0];                 // dmux > cpu
wire [3:0] debug_reg_sel[`CORES-1:0];                  // dmux > cpu
wire debug_reg_we[`CORES-1:0];                         // dmux > cpu
wire [`DATA_WIDTH-1:0] debug_reg_wdata[`CORES-1:0];    // dmux > cpu
wire debug_reg_stopped[`CORES-1:0];                    // dmux < cpu
wire [`DATA_WIDTH-1:0] debug_reg_rdata[`CORES-1:0];    // dmux < cpu

// between debugging multiplexer and cpu core (packed versions for debugging multiplexer)
wire [`CORES*2-1:0] debug_cpu_mode_raw;                // dmux > cpu
wire [`CORES*4-1:0] debug_reg_sel_raw;                 // dmux > cpu
wire [`CORES-1:0] debug_reg_we_raw;                    // dmux > cpu
wire [`CORES*`DATA_WIDTH-1:0] debug_reg_wdata_raw;     // dmux > cpu
wire [`CORES-1:0] debug_reg_stopped_raw;               // dmux < cpu
wire [`CORES*`DATA_WIDTH-1:0] debug_reg_rdata_raw;     // dmux < cpu

// between wishbone multiplexer and programming multiplexer
wire prog_we;                                          // wbmux > pmux
wire [`LOG_CORES-1:0] prog_sel;                        // wbmux > pmux
wire [`PC_WIDTH-1:0] prog_waddr;                       // wbmux > pmux
wire [`INSTR_WIDTH-1:0] prog_wdata;                    // wbmux > pmux

// between wishbone multiplexer and io pads
wire pads_we;                                          // wbmux > pads
wire pads_waddr;                                       // wbmux > pads
wire [`IO_PINS-1:0] pads_wdata;                        // wbmux > pads

// between wishbone multiplexer and debugging multiplexer
wire [`LOG_CORES-1:0] debug_sel;                       // wbmux > dmux
wire [4:0] debug_addr;                                 // wbmux > dmux
wire debug_we;                                         // wbmux > dmux
wire [`DATA_WIDTH-1:0] debug_wdata;                    // wbmux > dmux
wire [`DATA_WIDTH-1:0] debug_rdata;                    // wbmux < dmux

// between wishbone multiplexer and entropy pool
wire [`WB_WIDTH-1:0] entropy_word;                     // wbmux > ep

// between entropy pool and prng's
wire entropy_bit;                                      // ep > prng

// repeat for each cpu core
generate genvar core;
for(core=0; core<`CORES; core=core+1) begin:g_core

   // add the cpu core itself
   wire [`DATA_WIDTH-1:0] cpu_num = core;
   cpu_core cpu_core_inst (
      .clk(clk),
      .rst_n(rst_soft_n),
      .opcode(im_rdata[core]),
      .mem_rdata(mem_rdata[core]),
      .cpu_num(cpu_num),
      .prng_in(prng_random[core]),
      .debug_mode(debug_cpu_mode[core]),
      .debug_sel(debug_reg_sel[core]),
      .debug_we(debug_reg_we[core]),
      .debug_wdata(debug_reg_wdata[core]),
      .progctr(im_raddr[core]),
      .mem_we(mem_we[core]),
      .mem_waddr(mem_waddr[core]),
      .mem_wspread(mem_wspread[core]),
      .mem_wdata(mem_wdata[core]),
      .mem_raddr(mem_raddr[core]),
      .debug_stopped(debug_reg_stopped[core]),
      .debug_rdata(debug_reg_rdata[core])
   );

   // add its own pseudorandom number generator
   wire [`PRNG_STATE_BITS-1:0] index = core;
   prng_wrap prng_inst (
      .clk(clk),
      .rst_n(rst_prng_n),
      .index(index),
      .entropy(entropy_bit),
      .random(prng_random[core])
   );

   // convert memory mesh inputs: unpacked to packed
   assign mem_we_raw[core] = mem_we[core];
   assign mem_waddr_raw[core*`ADDR_WIDTH +: `ADDR_WIDTH] = mem_waddr[core];
   assign mem_wspread_raw[core*SPREAD_WIDTH +: SPREAD_WIDTH] = mem_wspread[core];
   assign mem_wdata_raw[core*`DATA_WIDTH +: `DATA_WIDTH] = mem_wdata[core];
   assign mem_raddr_raw[core*`ADDR_WIDTH +: `ADDR_WIDTH] = mem_raddr[core];

   // convert memory mesh outputs: packed to unpacked
   assign mem_rdata[core] = mem_rdata_raw[core*`DATA_WIDTH +: `DATA_WIDTH];

   // convert instruction memory inputs: unpacked to packed
   assign im_raddr_raw[core*`PC_WIDTH +: `PC_WIDTH] = im_raddr[core];

   // convert instruction memory outputs: packed to unpacked
   assign im_rdata[core] = im_rdata_raw[core*`INSTR_WIDTH +: `INSTR_WIDTH];

   // convert debugging multiplexer inputs: unpacked to packed
   assign debug_reg_stopped_raw[core] = debug_reg_stopped[core];
   assign debug_reg_rdata_raw[core*`DATA_WIDTH +: `DATA_WIDTH] = debug_reg_rdata[core];

   // convert debugging multiplexer outputs: packed to unpacked
   assign debug_cpu_mode[core] = debug_cpu_mode_raw[core*2 +: 2];
   assign debug_reg_sel[core] = debug_reg_sel_raw[core*4 +: 4];
   assign debug_reg_we[core] = debug_reg_we_raw[core];
   assign debug_reg_wdata[core] = debug_reg_wdata_raw[core*`DATA_WIDTH +: `DATA_WIDTH];

end
endgenerate

// add the memory mesh, with a packed bus towards the cpu cores
mem_mesh mem_mesh_inst (
   .clk(clk),
   .rst_n(rst_soft_n),
   .we(mem_we_raw),
   .waddr(mem_waddr_raw),
   .wspread(mem_wspread_raw),
   .wdata(mem_wdata_raw),
   .raddr(mem_raddr_raw),
   .rdata(mem_rdata_raw),
   .io_active_in(mem_io_active_in),
   .io_active_out(mem_io_active_out),
   .io_data_in(mem_io_data_in),
   .io_data_out(mem_io_data_out)
);

// add the io filter connected to the memory mesh
io_filter_rev io_filter_inst (
   .clk(clk),
   .rst_n(rst_soft_n),
   .pin_dir(pin_dir),
   .pin_data_in(pin_data_in),
   .pin_data_out(pin_data_out),
   .port_active_in(mem_io_active_in),
   .port_active_out(mem_io_active_out),
   .port_data_in(mem_io_data_in),
   .port_data_out(mem_io_data_out)
);

// add instruction memory blocks
instr_mem instr_mem_inst (
  .clk(clk),
  .rst_n(rst_hard_n),
  .raddr(im_raddr_raw),
  .rdata(im_rdata_raw),
  .we(im_we_raw),
  .waddr(im_waddr_raw),
  .wdata(im_wdata_raw)
);

// add the programming multiplexer
prog_mux prog_mux_inst (
   .we(prog_we),
   .sel(prog_sel),
   .waddr(prog_waddr),
   .wdata(prog_wdata),
   .cwe(im_we_raw),
   .cwaddr(im_waddr_raw),
   .cwdata(im_wdata_raw)
);

// add the debugging multiplexer, with a packed bus towards cpu cores
debug_mux debug_mux_inst (
   .sel(debug_sel),
   .addr(debug_addr),
   .we(debug_we),
   .wdata(debug_wdata),
   .rdata(debug_rdata),
   .reg_stopped(debug_reg_stopped_raw),
   .reg_rdata(debug_reg_rdata_raw),
   .cpu_mode(debug_cpu_mode_raw),
   .reg_sel(debug_reg_sel_raw),
   .reg_we(debug_reg_we_raw),
   .reg_wdata(debug_reg_wdata_raw)
);

// add the entropy pool
entropy_pool entropy_pool_inst (
   .clk(clk),
   .rst_n(rst_prng_n),
   .e_word(entropy_word),
   .e_bit(entropy_bit)
);

// add the wishbone multiplexer
wb_mux wb_mux_inst (
   .wbs_stb_i(wbs_stb_i),
   .wbs_cyc_i(wbs_cyc_i),
   .wbs_we_i(wbs_we_i),
   .wbs_adr_i(wbs_adr_i),
   .wbs_dat_i(wbs_dat_i),
   .wbs_ack_o(wbs_ack_o),
   .wbs_dat_o(wbs_dat_o),
   .prog_we(prog_we),
   .prog_sel(prog_sel),
   .prog_waddr(prog_waddr),
   .prog_wdata(prog_wdata),
   .pads_we(pads_we),
   .pads_waddr(pads_waddr),
   .pads_wdata(pads_wdata),
   .debug_sel(debug_sel),
   .debug_addr(debug_addr),
   .debug_we(debug_we),
   .debug_wdata(debug_wdata),
   .debug_rdata(debug_rdata),
   .entropy_word(entropy_word)
);

// add the io pads & logic analyzer probes
// (this includes some reset & clock logic as well)
io_pads io_pads_inst (
   .wb_clk_i(wb_clk_i),
   .wb_rst_i(wb_rst_i),
   .la_data_in(la_data_in),
   .la_data_out(la_data_out),
   .la_oenb(la_oenb),
   .io_in(io_in),
   .io_out(io_out),
   .io_oeb(io_oeb),
   .clk(clk),
   .rst_hard_n(rst_hard_n),
   .rst_soft_n(rst_soft_n),
   .rst_prng_n(rst_prng_n),
   .pin_dir(pin_dir),
   .pin_data_in(pin_data_in),
   .pin_data_out(pin_data_out),
   .cfg_we(pads_we),
   .cfg_addr(pads_waddr),
   .cfg_wdata(pads_wdata)
);

endmodule

`default_nettype wire

