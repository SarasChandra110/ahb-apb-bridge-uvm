# Questa simulation script for ahb-apb-bridge-uvm
# Runs the native SV/UVM testbench (not the cocotb version)
# Usage: vsim -do sim/run_questa.do
# Or:    cd sim && make questa

quietly set ROOT [file normalize [file dirname [info script]]/..]

vlib work
vmap work work

# UVM (built into Questa)
vlog -sv -work work +incdir+$::env(QUESTA_HOME)/verilog_src/uvm-1.2/src \
     $::env(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv

# RTL
vlog -sv -work work $ROOT/rtl/ahb_apb_bridge.sv

# TB
vlog -sv -work work +incdir+$::env(QUESTA_HOME)/verilog_src/uvm-1.2/src \
    $ROOT/tb/agents/ahb_seq_item.sv   \
    $ROOT/tb/agents/ahb_driver.sv     \
    $ROOT/tb/agents/ahb_monitor.sv    \
    $ROOT/tb/env/ahb_apb_scoreboard.sv \
    $ROOT/tb/env/ahb_apb_coverage.sv   \
    $ROOT/tb/tests/rand_test.sv

# Sim top (needs UVM run_test)
vlog -sv -work work +incdir+$::env(QUESTA_HOME)/verilog_src/uvm-1.2/src \
    $ROOT/tb/tb_top_questa.sv

vsim -sv_seed random \
     +UVM_TESTNAME=rand_test \
     +UVM_VERBOSITY=UVM_MEDIUM \
     -do "run -all; quit -f" \
     work.tb_top_questa
