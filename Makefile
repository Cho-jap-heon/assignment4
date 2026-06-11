SRC = mips.v control_unit.v hazard_unit.v \
      main_decoder.v alu_decoder.v \
      datapath.v pc.v instruction_memory.v \
      reg_file.v alu.v data_memory.v
TB  = mips_tb.v
OUT = mips.out
VCD = assignment_04.vcd

.PHONY: all compile run wave clean

all: compile run

compile:
	iverilog -o $(OUT) $(TB) $(SRC)
run:
	vvp -n $(OUT)
wave:
	gtkwave $(VCD) &
clean:
	-del /f /q $(OUT) 2>nul
	-del /f /q $(VCD) 2>nul
