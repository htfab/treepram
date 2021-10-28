// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Connection to Caravel IO pads & logic analyzer
*/

module io_pads (
   // Caravel interface
   input wb_clk_i,
   input wb_rst_i,
   input [`LOGIC_PROBES-1:0] la_data_in,
   output [`LOGIC_PROBES-1:0] la_data_out,
   input [`LOGIC_PROBES-1:0] la_oenb,
   input [`IO_PADS-1:0] io_in,
   output [`IO_PADS-1:0] io_out,
   output [`IO_PADS-1:0] io_oeb,
   // MCU interface
   output clk,
   output rst_hard_n,
   output rst_soft_n,
   output rst_prng_n,
   // IO filter interface
   output [`IO_PINS-1:0] pin_dir,
   output [`IO_PINS-1:0] pin_data_in,
   input [`IO_PINS-1:0] pin_data_out,
   // Wishbone multiplexer interface
   input cfg_we,
   input cfg_addr,
   input [`IO_PINS-1:0] cfg_wdata
);

reg programming;
reg [`IO_PINS-1:0] saved_dir;

// allow logic analyzer probes to override clock & reset signals
assign clk = la_oenb[0] ? wb_clk_i : la_data_in[0];
assign rst_hard_n = la_oenb[1] ? !wb_rst_i : la_data_in[1];
assign rst_soft_n = la_oenb[2] ? (!wb_rst_i & !programming) : la_data_in[2];
assign rst_prng_n = la_oenb[3] ? !wb_rst_i : la_data_in[3];

localparam LA_DIR = 4;                       // index of logic analyzer probes for pin directions
localparam LA_PIN = LA_DIR + `IO_PINS;       // index of logic analyzer probes for pin values
localparam LA_PAD = LA_PIN + `IO_PINS;       // index of logic analyzer probes for pad values
localparam LA_END = LA_PAD + `IO_PADS;       // index of first unused logic analyzer probe
localparam LA_REM = `LOGIC_PROBES - LA_END;  // unused logic analyzer probes

localparam PAD_REM = `IO_PADS - `IO_PINS - `FIRST_PAD;   // unused pads remaining after the last io pin

// while programming, all pins are inputs, otherwise they follow the saved_dir array
// the logic analyzer can override everything
assign pin_dir = (la_oenb[LA_DIR +: `IO_PINS] & (rst_soft_n ? saved_dir : 0)) |
                 (~la_oenb[LA_DIR +: `IO_PINS] & la_data_in[LA_DIR +: `IO_PINS]);

// pin values are read from corresponding pads as long as the pin direction is set to input
assign pin_data_in = (la_oenb[LA_PIN +: `IO_PINS] & ~pin_dir & io_in[`FIRST_PAD +: `IO_PINS]) |
                     (~la_oenb[LA_PIN +: `IO_PINS] & la_data_in[LA_PIN +: `IO_PINS]);

// configure pad directions according to pin directions, pads not matched to pins are marked as inputs
assign io_oeb = (la_oenb[LA_PAD +: `IO_PADS] & {{(PAD_REM){1'b1}}, ~pin_dir, {(`FIRST_PAD){1'b1}}}) |
                (~la_oenb[LA_PAD +: `IO_PADS] & {(`IO_PADS){1'b0}});

// pin values are written to corresponding pads, zeroes are written to unassigned pads (they are inputs anyway)
assign io_out = (la_oenb[LA_PAD +: `IO_PADS] & {{(PAD_REM){1'b0}}, pin_dir & pin_data_out, {(`FIRST_PAD){1'b0}}}) |
                (~la_oenb[LA_PAD +: `IO_PADS] & la_data_in[LA_PAD +: `IO_PADS]);

// logic analyzer probes can also read back the same signals and values
assign la_data_out[0] = wb_clk_i;
assign la_data_out[1] = rst_hard_n;
assign la_data_out[2] = rst_soft_n;
assign la_data_out[3] = rst_prng_n;
assign la_data_out[LA_DIR +: `IO_PINS] = pin_dir;
assign la_data_out[LA_PIN +: `IO_PINS] = pin_data_out;
assign la_data_out[LA_PAD +: `IO_PADS] = io_in;
assign la_data_out[LA_END +: LA_REM] = {(LA_REM){1'b0}};

// change programming mode & pin directions from the wishbone multiplexer
always @(posedge clk) begin
   if (!rst_hard_n) begin
      programming <= 0;
      saved_dir <= {(`IO_PINS){1'b0}};
   end else begin
      if (cfg_we) begin
         case (cfg_addr)
            0: programming <= cfg_wdata;
            1: saved_dir <= cfg_wdata;
         endcase
      end
   end
end

endmodule

`default_nettype wire

