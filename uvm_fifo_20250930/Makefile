# Simple Linux Makefile for QuestaSim + UVM 1.1d
# Usage:
#   make        # compile & run
#   make comp   # compile only
#   make run    # run only (after comp)
#   make gui    # launch GUI
#
# Expectation:
#   - env var UVM_HOME points to UVM 1.1d (contains src/uvm.sv)
#   - DUT is at ../apb_fifo_buggy.sv (adjust DUT?= below if needed)

QUESTA?=vsim
VLOG?=vlog
VSIM?=vsim
DUT?=apb_fifo_buggy.sv
TOP?=tb_top

UVM_DEFS=+define+UVM_NO_DEPRECATED +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
UVM_INC=+incdir+$(UVM_HOME)/src
UVM_FILE=$(UVM_HOME)/src/uvm.sv

TB_SRCS= \
  apb_if.sv \
  apb_pkg.sv \
  fifo_pkg.sv \
  env_pkg.sv \
  tests_pkg.sv \
  tb_top.sv

all: work run

work:
	vlib work || true
	vmap work work || true

comp_uvm: work
	$(VLOG) -sv +acc $(UVM_DEFS) $(UVM_INC) $(UVM_FILE)

comp_tb:
	$(VLOG) -sv +cover=bcesft +acc +incdir+. $(TB_SRCS)
	$(VLOG) -sv +cover=bcesft +acc +incdir+. $(DUT)

comp: comp_tb

run: comp
	$(VSIM) -c -sv_seed random -coverage -do "run -all; quit -f" $(TOP)

gui: comp
	$(VSIM) $(TOP)

clean:
	rm -rf work transcript vsim.wlf vsim.dbg modelsim.ini coverage.ucdb *.log

.PHONY: all comp comp_tb comp_uvm run gui clean work
