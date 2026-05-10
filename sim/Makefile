TOPLEVEL_LANG    = verilog

# Use Windows-style paths — cocotb on Windows needs backslash-free absolute paths
RTL_DIR  = C:/Users/Saras/ahb-apb-bridge-uvm/rtl
TB_DIR   = C:/Users/Saras/ahb-apb-bridge-uvm/tb

VERILOG_SOURCES  = $(RTL_DIR)/ahb_apb_bridge.sv $(TB_DIR)/tb_top.sv
TOPLEVEL         = tb_top
COCOTB_TEST_MODULES = test_bridge
COCOTB_HDL_TIMEUNIT      = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

export PYTHONPATH := $(TB_DIR)

SIM ?= icarus

include $(shell cocotb-config --makefiles)/Makefile.sim
