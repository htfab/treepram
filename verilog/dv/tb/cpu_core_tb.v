// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module cpu_core_tb();

parameter DATA_WIDTH = 16;
parameter PC_WIDTH = 8;
parameter ADDR_WIDTH = 8;
parameter SPREAD_WIDTH = 2;
parameter INSTR_WIDTH = 32;

reg clk;
reg rst_n;

wire [INSTR_WIDTH-1:0] opcode;
wire [PC_WIDTH-1:0] progctr;
wire mem_we;
wire [ADDR_WIDTH-1:0] mem_waddr;
wire [SPREAD_WIDTH-1:0] mem_wspread;
wire [DATA_WIDTH-1:0] mem_wdata;
wire [ADDR_WIDTH-1:0] mem_raddr;
wire [DATA_WIDTH-1:0] mem_rdata;
wire debug_stopped;
wire [DATA_WIDTH-1:0] debug_rdata;

cpu_core #(
   .DATA_WIDTH(DATA_WIDTH),
   .PC_WIDTH(PC_WIDTH),
   .ADDR_WIDTH(ADDR_WIDTH),
   .SPREAD_WIDTH(SPREAD_WIDTH),
   .INSTR_WIDTH(INSTR_WIDTH)
) cpu_core_dut (
   .clk(clk),
   .rst_n(rst_n),
   .opcode(opcode),
   .mem_rdata(mem_rdata),
   .prng_in(16'd0),
   .debug_mode(2'd0),
   .debug_sel(4'd6),
   .debug_we(1'd0),
   .debug_wdata(16'd0),
   .progctr(progctr),
   .mem_we(mem_we),
   .mem_waddr(mem_waddr),
   .mem_wspread(mem_wspread),
   .mem_wdata(mem_wdata),
   .mem_raddr(mem_raddr),
   .debug_stopped(debug_stopped),
   .debug_rdata(debug_rdata)
);

wire io_dummy_active;
wire [DATA_WIDTH-1:0] io_dummy_data;

mem_mesh #(
   .CORES(1),
   .DEPTH(16),
   .DATA_WIDTH(DATA_WIDTH),
   .ADDR_WIDTH(ADDR_WIDTH),
   .SPREAD_LAYERS(0),
   .SPREAD_WIDTH(SPREAD_WIDTH),
   .USE_IO(0),
   .IO_PORTS(1),
   .IO_FIRST(0)
) mem_mesh_dut (
   .clk(clk),
   .rst_n(rst_n),
   .we(mem_we),
   .waddr(mem_waddr),
   .wspread(mem_wspread),
   .wdata(mem_wdata),
   .raddr(mem_raddr),
   .rdata(mem_rdata),
   .io_dir(1'b1),
   .io_active(io_dummy_active),
   .io_data(io_dummy_data)
);

always #5 clk = ~clk;

reg [3:0] round;
wire [INSTR_WIDTH-1:0] noop  = 32'b000_000_0_00_0000_000_0000000000000000;
wire [INSTR_WIDTH-1:0] progmem ['h100:0];

localparam n_tests = 4;

// test 1
assign progmem['h00] = 32'b100_000_1_00_0011_001_0000000001001001;   // reg1 = 73
assign progmem['h01] = 32'b100_000_1_00_0011_010_0000000001001010;   // reg2 = 74
assign progmem['h02] = 32'b000_001_1_00_1010_011_0000000000000000;   // jmp reg1 + reg2

// test 2
assign progmem['h10] = 32'b100_000_1_00_0011_001_0000000011110011;   // reg1 = 243
assign progmem['h11] = 32'b000_000_1_11_0011_111_0000000000010000;   // mem[1] = reg1
assign progmem['h12] = 32'b100_000_1_00_0011_100_0000000000000000;   // t = mem[0]
assign progmem['h13] = 32'b011_111_1_11_1010_111_0000000000000000;   // mem[0] = t+1
assign progmem['h14] = 32'b100_000_1_00_0011_100_0000000000000000;   // t = mem[0]
assign progmem['h15] = 32'b011_000_1_00_0011_100_0000000000000000;   // t = mem[t]
assign progmem['h16] = 32'b011_000_1_00_0011_011_0000000000000000;   // jmp t

// test 3
assign progmem['h20] = 32'b110_100_1_00_1011_001_0000000000010111;   // reg1 = timer - 23
assign progmem['h21] = 32'b000_010_1_01_0011_011_0000000000000000;   // jmp (reg1 < 0) ? 0 : pc
assign progmem['h22] = 32'b100_000_1_00_0011_011_0000000000101100;   // jmp 44

// test 4
assign progmem['h30] = 32'b100_000_1_00_0011_010_0000000010001000;   // reg2 = 136
assign progmem['h31] = 32'b001_000_1_11_0011_111_0000000000100000;   // mem[2] = reg2
assign progmem['h32] = 32'b100_000_1_00_0011_100_0000000000000010;   // t = mem[2]
assign progmem['h33] = 32'b100_000_1_10_0011_010_0000000000010001;   // reg1 = t; reg2 = 17
assign progmem['h34] = 32'b000_001_1_00_1010_011_0000000000000000;   // jmp reg1 + reg2

assign opcode = rst_n ? (progctr < 16 ? progmem[round << 4 | progctr] : noop) : noop;

always @ (posedge clk) begin
   if (progctr >= 16) begin
      rst_n = 0;
      if (round + 1 >= n_tests) $finish;
      round = round + 1;
      $display("");
      #12 rst_n = 1;
   end
end

initial begin
   $monitor("time=%4t round=%1x rstn=%1b ct=%2d op=%32b new_pc=%8b(%2x) reg1=%16b we=%1b wa=%8b ws=%2b wd=%16b ra=%8b rd=%16b dd=%16b",
   $time, round, rst_n, cpu_core_dut.timer, opcode, progctr, progctr, cpu_core_dut.reg1,
   mem_we, mem_waddr, mem_wspread, mem_wdata, mem_raddr, mem_rdata, debug_rdata);
   round = 0;
   clk = 0;
   rst_n = 0;
   #12 rst_n = 1;
end

endmodule

`default_nettype wire

