// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2021 Tamas Hubai

`default_nettype none

// number of cpu cores
`define CORES 8

// number of memory mesh cells per cpu core
`define MEM_DEPTH 32

// machine word size
`define DATA_WIDTH 16

// minimum number of instructions in program memory (some cores will have a multiple of it)
`define INSTR_DEPTH 16

// number of io pins usable by code on cpu cores
`define IO_PINS 24

// map io pin 0 to caravel io pad `FIRST_PAD
`define FIRST_PAD 12

// wishbone bus width, fixed to 32
`define WB_WIDTH 32

// number of caravel logic analyzer probes
`define LOGIC_PROBES 128

// number of caravel io pads
`define IO_PADS `MPRJ_IO_PADS

// opcode width including args, should be fixed at 32 or opcode handling needs to be changed
`define INSTR_WIDTH 32

// size of lfsr for prng, should be fixed at 32 or polynomials need to be updated
`define PRNG_STATE_BITS 32

`define LOG_CORES $clog2(`CORES)
`define SPREAD_WIDTH $clog2(2 + `LOG_CORES)
`define ADDR_WIDTH $clog2(`MEM_DEPTH)
`define PC_WIDTH ($clog2(`INSTR_DEPTH) + $clog2(`CORES))
`define MEM_IO_PORTS (2 + `IO_PINS)
`define MEM_IO_FIRST (`MEM_DEPTH - `MEM_IO_PORTS)
`define MEM_IO_LAST1 `MEM_DEPTH

`default_nettype wire

