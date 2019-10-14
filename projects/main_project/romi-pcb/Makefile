PROJ = top
DEVICE = lp8k
BOARD = romi-board
SOURCES = $(PROJ).v ../../../boards/$(BOARD)/pll_50mhz.v ../hba_system.v ../../../serial_fpga/serial_fpga.v ../../../serial_fpga/send_recv.v ../../../common/uart.v ../../../common/hba_master.v ../../../common/hba_arbiter.v ../../../common/hba_or_masters.v ../../../common/hba_or_slaves.v ../../../hba_reg_bank/hba_reg_bank.v ../../../hba_sonar/hba_sonar.v ../../../hba_sonar/sr04.v ../../../hba_basicio/hba_basicio.v ../../../hba_motor/hba_motor.v ../../../hba_motor/pwm_dir.v ../../../hba_qtr/hba_qtr.v ../../../hba_qtr/qtr.v ../../../hba_quad/hba_quad.v ../../../hba_quad/quadrature.v ../../../hba_quad/pulse_counter.v ../../../hba_quad/timer_pulse.v

PIN_DEF = ../../../boards/$(BOARD)/pins_pcb.pcf

all: $(PROJ).rpt $(PROJ).bin

%.blif: $(SOURCES)
	yosys -p 'synth_ice40 -top $(PROJ) -blif $@' $^

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -s 7 -d 8k -P cm81 -o $@ -p $^

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

%_tb: %_tb.v %.v
	iverilog -o $@ $^

%_tb.vcd: %_tb
	vvp -N $< +vcd=$@

%_syn.v: %.blif
	yosys -p 'read_blif -wideports $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v
	iverilog -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

%_syntb.vcd: %_syntb
	vvp -N $< +vcd=$@

prog: $(PROJ).bin
	tinyprog -p $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo tinyprog -p $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
