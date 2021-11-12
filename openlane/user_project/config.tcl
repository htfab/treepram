# SPDX-FileCopyrightText: 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

set script_dir [file dirname [file normalize [info script]]]

set ::env(DESIGN_NAME) user_project

set ::env(VERILOG_FILES) "\
	$::env(CARAVEL_ROOT)/verilog/rtl/defines.v \
	$script_dir/../../verilog/rtl/defines.v \
	$script_dir/../../verilog/rtl/user_project.v \
	$script_dir/../../verilog/rtl/mcu.v \
	$script_dir/../../verilog/rtl/cpu_core.v \
	$script_dir/../../verilog/rtl/alu.v \
	$script_dir/../../verilog/rtl/instr_mem.v \
	$script_dir/../../verilog/rtl/prng_wrap.v \
	$script_dir/../../verilog/rtl/prng.v \
	$script_dir/../../verilog/rtl/mem_mesh.v \
	$script_dir/../../verilog/rtl/io_filter_rev.v \
	$script_dir/../../verilog/rtl/io_filter.v \
	$script_dir/../../verilog/rtl/pin_compress.v \
	$script_dir/../../verilog/rtl/pin_decompress.v \
	$script_dir/../../verilog/rtl/prog_mux.v \
	$script_dir/../../verilog/rtl/debug_mux.v \
	$script_dir/../../verilog/rtl/entropy_pool.v \
	$script_dir/../../verilog/rtl/wb_mux.v \
	$script_dir/../../verilog/rtl/io_pads.v"
 
set ::env(DESIGN_IS_CORE) 0

set ::env(CLOCK_PORT) "mcu_inst.clk"
set ::env(CLOCK_NET) "mcu_inst.clk"
set ::env(CLOCK_PERIOD) "30"

set ::env(SYNTH_STRATEGY) "DELAY 1"

set ::env(FP_SIZING) relative
set ::env(FP_CORE_UTIL) 28

set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg

#set ::env(PL_BASIC_PLACEMENT) 1
set ::env(PL_TARGET_DENSITY) 0.288

# This requires a patched openroad & openlane, see the "patch" directory at the repo root
set ::env(DECAP_PERCENT) 75

# Maximum layer used for routing is metal 4.
# This is because this macro will be inserted in a top level (user_project_wrapper) 
# where the PDN is planned on metal 5. So, to avoid having shorts between routes
# in this macro and the top level metal 5 stripes, we have to restrict routes to metal4.  
set ::env(GLB_RT_MAXLAYER) 5

# You can draw more power domains if you need to 
set ::env(VDD_NETS) [list {vccd1}]
set ::env(GND_NETS) [list {vssd1}]

set ::env(DIODE_INSERTION_STRATEGY) 4 
# If you're going to use multiple power domains, then disable cvc run.
set ::env(RUN_CVC) 1
