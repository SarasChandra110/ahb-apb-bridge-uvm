TOPLEVEL_LANG    = verilog

# $(CURDIR) = absolute path of sim/ directory — works on both Windows and Linux
VERILOG_SOURCES  = $(CURDIR)/../rtl/ahb_apb_bridge.sv \
                   $(CURDIR)/../tb/tb_top.sv
TOPLEVEL         = tb_top
COCOTB_TEST_MODULES = test_bridge
COCOTB_HDL_TIMEUNIT      = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

export PYTHONPATH := $(CURDIR)/../tb

SIM ?= icarus

include $(shell cocotb-config --makefiles)/Makefile.sim
