// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

module wb_mux_tb();

parameter LOG_CORES = 3;
parameter PC_WIDTH = 8;
parameter INSTR_WIDTH = 32;
parameter DATA_WIDTH = 16;
parameter IO_PINS = 16;
parameter WB_WIDTH = 32;

reg wb_stb_i;
reg wb_cyc_i;
reg wb_we_i;
reg [WB_WIDTH-1:0] wb_adr_i;
reg [WB_WIDTH-1:0] wb_dat_i;
wire wbs_ack_o;
wire [WB_WIDTH-1:0] wbs_dat_o;
wire prog_we;
wire [LOG_CORES-1:0] prog_sel;
wire [PC_WIDTH-1:0] prog_waddr;
wire [INSTR_WIDTH-1:0] prog_wdata;
wire pads_we;
wire pads_waddr;
wire [IO_PINS-1:0] pads_wdata;
wire [LOG_CORES-1:0] debug_sel;
wire [4:0] debug_addr;
wire debug_we;
wire [DATA_WIDTH-1:0] debug_wdata;
reg [DATA_WIDTH-1:0] debug_rdata;
wire [WB_WIDTH-1:0] entropy_word;

wb_mux #(
   .LOG_CORES(LOG_CORES),
   .PC_WIDTH(PC_WIDTH),
   .INSTR_WIDTH(INSTR_WIDTH),
   .DATA_WIDTH(DATA_WIDTH),
   .IO_PINS(IO_PINS),
   .WB_WIDTH(WB_WIDTH)
) wb_mux_dut (
   .wb_stb_i(wb_stb_i),
   .wb_cyc_i(wb_cyc_i),
   .wb_we_i(wb_we_i),
   .wb_adr_i(wb_adr_i),
   .wb_dat_i(wb_dat_i),
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

initial begin
   $monitor("time %4t / wa %1b wdo %32b / pwe %1b ps %3b pwa %8b pwd %32b / awe %1b aa %1b awd %16b / ds %3b da %5b dwe %1b dwd %16b / ew %32b",
      $time, wbs_ack_o, wbs_dat_o, prog_we, prog_sel, prog_waddr, prog_wdata, pads_we, pads_waddr, pads_wdata,
      debug_sel, debug_addr, debug_we, debug_wdata, entropy_word);
   // before cycle
   wb_stb_i = 0;
   wb_cyc_i = 0;
   wb_we_i = 0;
   wb_adr_i = 0;
   wb_dat_i = 32'b11111111111111111111111111111111;
   debug_rdata = 16'b1111000010101010;
   #10
   // prog read (no effect)
   wb_stb_i = 1;
   wb_cyc_i = 1;
   wb_adr_i = 32'b00_0000000000000000000_101_11011011;
   #10
   // prog write
   wb_we_i = 1;
   #10
   // pads read (no effect)
   wb_we_i = 0;
   wb_adr_i = 32'b01_000000000000000000000000000001;
   #10
   // pads write
   wb_we_i = 1;
   #10
   // debug read
   wb_we_i = 0;
   wb_adr_i = 32'b10_0000000000000000000000_010_01010;
   #10
   // debug write
   wb_we_i = 1;
   #10
   // entropy read (no effect)
   wb_we_i = 0;
   wb_adr_i = 32'b11_000000000000000000000000000000;
   #10
   // entropy write
   wb_we_i = 1;
   #10
   // after cycle
   wb_stb_i = 0;
   wb_cyc_i = 0;
   #10
   $stop;
end

endmodule

`default_nettype wire

