# Questa/Modelsim run script (UVM 1.1d)
# Usage inside Questa: do run.do
# Make sure environment variable UVM_HOME points to UVM 1.1d installation.

vlib work
vmap work work

# Compile UVM (assumes $UVM_HOME is set)
vlog -sv +acc +define+UVM_NO_DEPRECATED +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR +incdir+$UVM_HOME/src $UVM_HOME/src/uvm.sv

# Compile TB
vlog -sv +incdir+. apb_if.sv
vlog -sv +incdir+. apb_pkg.sv
vlog -sv +incdir+. fifo_pkg.sv
vlog -sv +incdir+. env_pkg.sv
vlog -sv +incdir+. tests_pkg.sv

# Compile DUT provided by user
vlog -sv +incdir+. ../apb_fifo_buggy.sv

# Compile top
vlog -sv +incdir+. tb_top.sv

# Run
vsim -c -sv_seed random -coverage -do "run -all; quit -f" tb_top
