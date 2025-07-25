MODULE = hp_core
VERILATOR = verilator
VCD_OUT = vlt_dump.vcd

# Automatically find all RTL and TB sources
SRC_VERILOG := $(wildcard rtl/*.v rtl/*.sv)
SRC_CPP     := $(wildcard tb/*.cpp tb/*.cc)
ALL_SOURCES := $(SRC_VERILOG) $(SRC_CPP)

# Generate C++ in executable form
VERILATOR_FLAGS += -cc --exe
# Generate makefile dependencies (not shown as complicates the Makefile)
#VERILATOR_FLAGS += -MMD
# Optimize
VERILATOR_FLAGS += -x-assign fast
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wall
# Make waveforms
VERILATOR_FLAGS += --trace-vcd
# Check SystemVerilog assertions
VERILATOR_FLAGS += --assert
# Generate coverage analysis
VERILATOR_FLAGS += --coverage
# Run Verilator in debug mode
#VERILATOR_FLAGS += --debug
# Add this trace to get a backtrace in gdb
#VERILATOR_FLAGS += --gdbbt

.PHONY: all verilate build simulate coverage waves clean

all: simulate

# 1) Run Verilator to generate C++ simulation files
verilate: .stamp.verilate

.stamp.verilate: $(ALL_SOURCES)
	@echo
	@echo "### VERILATING ###"
	$(VERILATOR) $(VERILATOR_FLAGS) \
	  $(SRC_VERILOG) $(SRC_CPP)
	@touch .stamp.verilate

# 2) Build the C++ simulation using the Verilator‑generated Makefile
build: obj_dir/V$(MODULE)

obj_dir/V$(MODULE): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	$(MAKE) -C obj_dir -f V$(MODULE).mk V$(MODULE)

# 3) Run the simulation (produces VCD and coverage data)
simulate: build
	@echo
	@echo "### SIMULATING ###"
	@rm -rf logs
	@mkdir -p logs
	@obj_dir/V$(MODULE) +trace

# 4) Generate annotated coverage
coverage:
	@echo
	@echo "### COVERAGE ###"
	@rm -rf logs/annotated
	verilator_coverage --annotate logs/annotated logs/coverage.dat

# 5) View the waveform
waves:
	@echo
	@echo "### OPENING GTKWave ###"
	gtkwave $(VCD_OUT)

# 6) Cleanup
clean:
	@echo "### CLEANING ###"
	@rm -rf .stamp.* obj_dir logs *.log *.dmp *.vcd coverage.dat core

