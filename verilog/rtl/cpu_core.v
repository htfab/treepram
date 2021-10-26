// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

/*
Central processing unit (single core)

Has two general-purpose registers and a carry flag and executes an instruction on every clock cycle.
Fetches instructions via the progctr (out) and opcode (in) ports. Each opcode instructs te cpu to
take two values from registers, memory or other sources, feed them through the ALU and put the
results in a register or memory cell or use it as a jump target.

Opcode structure assumes `INSTR_WIDTH=32. Changing it requires substantial edits to the code below.

Opcodes have 32 bits and use the following format:
AAA BBB C DD EEEE FFF GGGGGGGGGGGGGGGG
A = source for ALU input 1
B = source for ALU input 2
C = reset carry flag used as ALU input
D = extra options, see below
E = ALU opcode
F = target for ALU result
G = immediate value, can be used as a source

Possible values for sources A & B:
000   use register 1
001   use register 2
010   use program counter
011   read value from memory address previously specified
100   use immediate value
101   use high (A) or low (B) 8 bits of immediate value
110   use timer (A) or prng (B)
111   use cpu number (A) or the constant 1 (B)

Possible values for target F:
000   ignore
001   set register 1
010   set register 2
011   set program counter (jump)
100   set memory read address
101   set memory write address
110   set spread value for memory write
111   write value to memory address previously specified

Possible values for ALU opcode E and how they use/set the carry flag are described in the
ALU source header.

Extra options in D were chosen to make classic Random Access Machine operations more
succinct. They are:
00    business as usual
01    set carry to highest bit of input 1 (specified as source A)
      then replace input 1 with the immediate value;
      also toggle this carry flag if C was set (and don't clear it, of course)
10    read value from memory and store it in register 1
      (if the instruction uses register 1 as the target, store it in register 2 instead)
11    set memory write address/spread/data based on the immediate value
      (if write data is set in this operation, it also triggers a memory write)
      if F==101 (address set from alu out): D ssss ddddddddddd = immediate
      if F==110 (spread set from alu out):  D aaaaaaaa ddddddd = immediate
      otherwise:                            A aaaaaaaaaaa ssss = immediate
      if the D or A bit is present, use register 1 for data/address instead
      and use the rest of the immediate value for the other part (aaa/sss/ddd)

Example opcodes to implement Random Access Machine instructions:

* M[i] = 0              // set memory slot i to zero
  000 000 1 11 0010 111 0iiiiiiiiiii0000

* M[i] = M[i] + 1       // increment value in memory slot i
  100 000 1 00 0011 100 iiiiiiiiiiiiiiii
  011 111 1 11 1010 111 0iiiiiiiiiii0000

* M[i] = M[i] - 1       // decrement value in memory slot i
  100 000 1 00 0011 100 iiiiiiiiiiiiiiii
  011 111 1 11 1011 111 0iiiiiiiiiii0000

* M[i] = M[i] + M[j]    // add value in memory slot j to memory slot i
  100 000 1 00 0011 100 jjjjjjjjjjjjjjjj
  100 000 1 10 0011 100 iiiiiiiiiiiiiiii
  011 000 1 11 1010 111 0iiiiiiiiiii0000

* M[i] = M[i] - M[j]    // subtract value in memory slot j from memory slot i
  100 000 1 00 0011 100 jjjjjjjjjjjjjjjj
  100 000 1 10 0011 100 iiiiiiiiiiiiiiii
  011 000 1 11 1011 111 0iiiiiiiiiii0000

* M[M[i]] = M[j]        // set memory pointed to by slot i to value in slot j
  100 000 1 00 0011 100 iiiiiiiiiiiiiiii
  100 000 1 10 0011 100 jjjjjjjjjjjjjjjj
  011 000 1 11 0011 111 1000000000000000

* M[i] = M[M[j]]        // set value in slot i to memory pointed to by slot j
  100 000 1 00 0011 100 jjjjjjjjjjjjjjjj
  011 000 1 00 0011 100 0000000000000000
  011 000 1 11 0011 111 0iiiiiiiiiii0000

* if M[i] < 0 goto j    // conditional jump
  100 000 1 00 0011 100 iiiiiiiiiiiiiiii
  011 010 1 01 0011 011 jjjjjjjjjjjjjjjj

*/

module cpu_core (
   input clk,                              // clock signal
   input rst_n,                            // reset, active low
   input [`INSTR_WIDTH-1:0] opcode,        // opcode to be executed & immediate args
   input [`DATA_WIDTH-1:0] mem_rdata,      // connected to 'rdata' of memory module
   input [`DATA_WIDTH-1:0] cpu_num,        // id to differentiate cpu cores
   input [`DATA_WIDTH-1:0] prng_in,        // random number from prng
   input [1:0] debug_mode,                 // debug: 00 = no change, 01 = single step, 10 = run, 11 = stop
   input [3:0] debug_sel,                  // debug: cpu status register to query or modify
   input debug_we,                         // debug: modify selected status register
   input [`DATA_WIDTH-1:0] debug_wdata,    // debug: new value of selected status register
   output [`PC_WIDTH-1:0] progctr,         // program counter
   output mem_we,                          // +-
   output [`ADDR_WIDTH-1:0] mem_waddr,     // | connected to
   output [`SPREAD_WIDTH-1:0] mem_wspread, // | corresponding ports
   output [`DATA_WIDTH-1:0] mem_wdata,     // | of memory module
   output [`ADDR_WIDTH-1:0] mem_raddr,     // +-
   output debug_stopped,                   // debug: read back whether core is stopped
   output [`DATA_WIDTH-1:0] debug_rdata    // debug: current value of selected status register
);

reg [`DATA_WIDTH-1:0] reg1;      // general-purpose registers
reg [`DATA_WIDTH-1:0] reg2;
reg carry;                       // carry flag
reg [`DATA_WIDTH-1:0] pc;        // register for program counter
reg [`DATA_WIDTH-1:0] timer;     // clock ticks since last reset
reg [`ADDR_WIDTH-1:0] raddr;     // next read address
reg we;                          // write to memory on next cycle
reg [`ADDR_WIDTH-1:0] waddr;     // next write address
reg [`SPREAD_WIDTH-1:0] wspread; // next write spread
reg [`DATA_WIDTH-1:0] wdata;     // next write data
reg stopped;                     // cpu core is stopped

assign progctr = pc;
assign mem_we = we;
assign mem_waddr = waddr;
assign mem_wspread = wspread;
assign mem_wdata = wdata;
assign mem_raddr = raddr;

// opcode subdivision
wire [2:0] op_in1;     // input 1 source
wire [2:0] op_in2;     // input 2 source
wire op_rst_carry;     // reset carry flag
wire [1:0] op_extra;   // extra steps before alu processing
wire [3:0] op_alu;     // send this opcode (and in1, in2, carry) to the alu
wire [2:0] op_target;  // target for alu result
wire [15:0] op_immed;  // hardcoded value(s) to use as an input source
assign {op_in1, op_in2, op_rst_carry, op_extra, op_alu, op_target, op_immed} = opcode;

wire op_extra_carry = op_extra == 1;   // set carry based on in1, replace in1 with immediate
wire op_extra_rdata = op_extra == 2;   // copy rdata to reg1 (or reg2 if reg1 is the target)
wire op_extra_waddr = op_extra == 3;   // fill waddr & wspread from immediate

wire [`DATA_WIDTH-1:0] next_pc = pc + 1;

wire [`DATA_WIDTH-1:0] sources1[7:0];
assign sources1[0] = reg1;
assign sources1[1] = reg2;
assign sources1[2] = next_pc;
assign sources1[3] = mem_rdata;
assign sources1[4] = op_immed;
assign sources1[5] = op_immed[15:8];
assign sources1[6] = timer;
assign sources1[7] = cpu_num;

wire [`DATA_WIDTH-1:0] sources2[7:0];
assign sources2[0] = reg1;
assign sources2[1] = reg2;
assign sources2[2] = next_pc;
assign sources2[3] = mem_rdata;
assign sources2[4] = op_immed;
assign sources2[5] = op_immed[7:0];
assign sources2[6] = prng_in;
assign sources2[7] = 1;

wire [`DATA_WIDTH-1:0] in1_orig = sources1[op_in1];                   // data to use as alu input 1, unless overridden by op_extra_carry
wire in1_oh = in1_orig[`DATA_WIDTH-1];                                // highest bit of in1_orig
wire [`DATA_WIDTH-1:0] in1 = op_extra_carry ? op_immed : in1_orig;    // data to use as alu input 1
wire [`DATA_WIDTH-1:0] in2 = sources2[op_in2];                        // data to use as alu input 2
wire carry_def = op_rst_carry ? 0 : carry;                            // carry to use as alu input, unless overridden by op_extra_carry
wire carry_ovr = op_rst_carry ? ~in1_oh : in1_oh;                     // override value if op_extra_carry is set
wire alu_cin = op_extra_carry ? carry_ovr : carry_def;                // consolidated carry input for alu

wire [`DATA_WIDTH-1:0] alu_out;                                       // data output from alu
wire alu_cout;                                                        // carry output from alu

alu alu_inst (
   .opcode(op_alu),
   .in1(in1),
   .in2(in2),
   .carry(alu_cin),
   .out(alu_out),
   .carry_out(alu_cout)
);

wire op_target_reg1    = op_target == 1;
wire op_target_reg2    = op_target == 2;
wire op_target_pc      = op_target == 3;
wire op_target_raddr   = op_target == 4;
wire op_target_waddr   = op_target == 5;
wire op_target_wspread = op_target == 6;
wire op_target_wdata   = op_target == 7;

// extract values from immediate to prepare for op_extra_waddr case
wire immed_ovr = op_immed[15];
wire [`DATA_WIDTH-1:0] s_hi4  = immed_ovr ? op_immed[14:0] : op_immed[14:11];
wire [`DATA_WIDTH-1:0] d_lo11 = immed_ovr ? reg1 : op_immed[10:0];
wire [`DATA_WIDTH-1:0] a_hi8  = immed_ovr ? op_immed[14:0] : op_immed[14:7];
wire [`DATA_WIDTH-1:0] d_lo7  = immed_ovr ? reg1 : op_immed[6:0];
wire [`DATA_WIDTH-1:0] a_hi11 = immed_ovr ? reg1 : op_immed[14:4];
wire [`DATA_WIDTH-1:0] s_lo4  = immed_ovr ? op_immed[14:0] : op_immed[3:0];

// update target with alu output
// if op_extra_rdata is set, also write mem_rdata to reg1 (if target is reg1, use reg2 instead)
// if op_extra_waddr is set, also fill waddr & wspread with immediate (if target is waddr/wspread, replace with wdata)
wire [`DATA_WIDTH-1:0] reg1_mod = op_target_reg1 ? alu_out : (op_extra_rdata ? mem_rdata : reg1);
wire [`DATA_WIDTH-1:0] reg2_mod = op_target_reg2 ? alu_out : ((op_extra_rdata && op_target_reg1) ? mem_rdata : reg2);
wire [`DATA_WIDTH-1:0] pc_mod = op_target_pc ? alu_out : next_pc;
wire [`DATA_WIDTH-1:0] raddr_mod = op_target_raddr ? alu_out : raddr;
wire [`DATA_WIDTH-1:0] waddr_mod = op_target_waddr ? alu_out :
                          (op_extra_waddr ? (op_target_wspread ? a_hi8 : a_hi11) : waddr);
wire [`DATA_WIDTH-1:0] wspread_mod = op_target_wspread ? alu_out :
                          (op_extra_waddr ? (op_target_waddr ? s_hi4 : s_lo4) : wspread);
wire [`DATA_WIDTH-1:0] wdata_mod = op_target_wdata ? alu_out :
                          (op_extra_waddr ? (op_target_wspread ? d_lo7 : (op_target_waddr ? d_lo11 : wdata)) : wdata);
wire we_mod = op_target_wdata || (op_extra_waddr && (op_target_waddr || op_target_wspread));

// debug interface
wire [`DATA_WIDTH-1:0] debug_reg[15:0];
assign debug_reg[0] = pc;
assign debug_reg[1] = opcode[31:16];
assign debug_reg[2] = opcode[15:0];
assign debug_reg[3] = reg1;
assign debug_reg[4] = reg2;
assign debug_reg[5] = carry;
assign debug_reg[6] = alu_out;
assign debug_reg[7] = alu_cout;
assign debug_reg[8] = timer;
assign debug_reg[9] = prng_in;
assign debug_reg[10] = raddr;
assign debug_reg[11] = mem_rdata;
assign debug_reg[12] = we;
assign debug_reg[13] = waddr;
assign debug_reg[14] = wspread;
assign debug_reg[15] = wdata;
assign debug_rdata = debug_reg[debug_sel];
assign debug_stopped = stopped;
wire stopped_mod = debug_mode[1] ? debug_mode[0] : stopped;

// sequential logic
always @ (posedge clk) begin
   if (!rst_n) begin
      reg1 <= 0;
      reg2 <= 0;
      carry <= 0;
      pc <= 0;
      timer <= 0;
      raddr <= 0;
      we <= 0;
      waddr <= 0;
      wspread <= 0;
      wdata <= 0;
      stopped <= 0;
   end else begin
      if (debug_we) begin
         // don't run instructions on cycles with debug writes
         case (debug_sel)
            // wires can't be changed, only regs
            0: pc <= debug_wdata;
            // opcode high & low skipped
            3: reg1 <= debug_wdata;
            4: reg2 <= debug_wdata;
            5: carry <= debug_wdata;
            // alu_out & alu_cout skipped
            8: timer <= debug_wdata;
            // prng_in skipped
            10: raddr <= debug_wdata;
            // mem_rdata skipped
            12: we <= debug_wdata;
            13: waddr <= debug_wdata;
            14: wspread <= debug_wdata;
            15: wdata <= debug_wdata;
         endcase
      end else if (!stopped_mod || debug_mode == 2'b01) begin
         // running or single stepping
         reg1 <= reg1_mod;
         reg2 <= reg2_mod;
         carry <= alu_cout;
         pc <= pc_mod;
         timer <= timer + 1;
         raddr <= raddr_mod;
         we <= we_mod;
         waddr <= waddr_mod;
         wspread <= wspread_mod;
         wdata <= wdata_mod;
         stopped <= stopped_mod;
      end
   end
end

endmodule

`default_nettype wire

