// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module mcu_tb();

parameter CORES = 2;
parameter LOG_CORES = 1;
parameter MEM_DEPTH = 16;
parameter DATA_WIDTH = 16;
parameter PC_WIDTH = 3;
parameter ADDR_WIDTH = 4;
parameter INSTR_WIDTH = 32;
parameter INSTR_DEPTH = 4;
parameter IN_PINS = 4;
parameter OUT_PINS = 4;
parameter IO_PADS = 38;
parameter FIRST_PAD = 12;
parameter LOGIC_PROBES = 128;
parameter WB_WIDTH = 32;
parameter IO_PINS = IN_PINS + OUT_PINS;

reg clk;
wire wb_clk_i = clk;
reg wb_rst_i;
reg wb_stb_i;
reg wb_cyc_i;
reg wb_we_i;
reg [WB_WIDTH-1:0] wb_adr_i;
reg [WB_WIDTH-1:0] wb_dat_i;
wire wbs_ack_o;
wire [WB_WIDTH-1:0] wbs_dat_o;
reg [LOGIC_PROBES-1:0] la_data_in;
wire [LOGIC_PROBES-1:0] la_data_out;
reg [LOGIC_PROBES-1:0] la_oenb;
wire [IO_PADS-1:0] io_in;
wire [IO_PADS-1:0] io_out;
wire [IO_PADS-1:0] io_oeb;

mcu #(
   .CORES(CORES),
   .LOG_CORES(LOG_CORES),
   .MEM_DEPTH(MEM_DEPTH),
   .DATA_WIDTH(DATA_WIDTH),
   .PC_WIDTH(PC_WIDTH),
   .ADDR_WIDTH(ADDR_WIDTH),
   .INSTR_WIDTH(INSTR_WIDTH),
   .INSTR_DEPTH(INSTR_DEPTH),
   .IO_PINS(IO_PINS),
   .IO_PADS(IO_PADS),
   .FIRST_PAD(FIRST_PAD),
   .LOGIC_PROBES(LOGIC_PROBES),
   .WB_WIDTH(WB_WIDTH)
) mcu_dut (
   .wb_clk_i(wb_clk_i),
   .wb_rst_i(wb_rst_i),
   .wb_stb_i(wb_stb_i),
   .wb_cyc_i(wb_cyc_i),
   .wb_we_i(wb_we_i),
   .wb_adr_i(wb_adr_i),
   .wb_dat_i(wb_dat_i),
   .wbs_ack_o(wbs_ack_o),
   .wbs_dat_o(wbs_dat_o),
   .la_data_in(la_data_in),
   .la_data_out(la_data_out),
   .la_oenb(la_oenb),
   .io_in(io_in),
   .io_out(io_out),
   .io_oeb(io_oeb)
);

reg [IN_PINS-1:0] pin_data_in;
assign io_in = {{(IO_PADS - IN_PINS - FIRST_PAD){1'b0}}, pin_data_in, {(FIRST_PAD){1'b0}}};

wire [OUT_PINS-1:0] pin_data_out = io_out[FIRST_PAD + IN_PINS +: OUT_PINS];

always #5 clk = ~clk;

initial begin
   $monitor("time %4t rh %1b rs %1b wwei %1b wai %32b pdi %4b pdo %4b",
               $time, la_data_out[1], la_data_out[2], wb_we_i, wb_adr_i, pin_data_in, pin_data_out);
   // power up
   clk = 0;
   wb_rst_i = 1;
   wb_stb_i = 0;
   wb_cyc_i = 0;
   wb_we_i = 0;
   wb_adr_i = 0;
   wb_dat_i = 0;
   la_data_in = {(LOGIC_PROBES){1'b0}};
   la_oenb = {(LOGIC_PROBES){1'b1}};
   pin_data_in = 4'b0000;
   #10
   // wishbone reset off, start communications
   wb_rst_i = 0;
   wb_stb_i = 1;
   wb_cyc_i = 1;
   wb_we_i = 1;
   // programming mode
   wb_adr_i = 32'b01_000000000000000000000000000000;           // set programming mode
   wb_dat_i = 32'b00000000000000000000000000000001;            // to 1
   #10
   // send code for cpu core 0
   wb_adr_i = 32'b00_00000000000000000000000000_0_000;         // address 0:
   wb_dat_i = 32'b100_000_1_00_0011_100_0000000000001111;      // read value from memory cell 15 (joined input)
   #10
   wb_adr_i = 32'b00_00000000000000000000000000_0_001;         // address 1:
   wb_dat_i = 32'b011_000_1_11_0011_111_0000000000000001;      // write value to memory cell 0, spread 1
   #10
   wb_adr_i = 32'b00_00000000000000000000000000_0_010;         // address 2:
   wb_dat_i = 32'b100_000_1_00_0011_011_0000000000000000;      // jump to address 0
   #10
   // send code for cpu core 1
   wb_adr_i = 32'b00_00000000000000000000000000_1_000;         // address 0:
   wb_dat_i = 32'b100_000_1_00_0011_100_0000000000000000;      // read value from memory cell 0
   #10
   wb_adr_i = 32'b00_00000000000000000000000000_1_001;         // address 1:
   wb_dat_i = 32'b011_000_1_11_0011_111_0000000011100010;      // write value to memory cell 14, spread 2 (joined output)
   #10
   wb_adr_i = 32'b00_00000000000000000000000000_1_010;         // address 2:
   wb_dat_i = 32'b100_000_1_00_0011_011_0000000000000000;      // jump to address 0
   #10
   // set pin directions
   wb_adr_i = 32'b01_000000000000000000000000000001;           // set pin directions
   wb_dat_i = 32'b00000000000000000000000011110000;            // first 4 pins are inputs, next 4 pins are outputs
   #10
   // exit programming mode
   wb_adr_i = 32'b01_000000000000000000000000000000;           // set programming mode
   wb_dat_i = 32'b00000000000000000000000000000000;            // to 0
   #10
   // stop wishbone communications
   wb_we_i = 0;
   wb_cyc_i = 0;
   wb_stb_i = 0;
   // set input pins
   pin_data_in = 4'b0011;
   // wait for data to appear on output pins
   #100
   // change input pins
   pin_data_in = 4'b1001;
   // wait for data to appear on output pins
   #100
   // change input pins
   pin_data_in = 4'b1100;
   // wait for data to appear on output pins
   #100
   $stop;
end

endmodule

`default_nettype wire

