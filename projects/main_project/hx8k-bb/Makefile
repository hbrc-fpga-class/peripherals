PROJ = top
DEVICE = hx8k
BOARD = hx8k-bb
SOURCES = $(PROJ).v ../../../boards/$(BOARD)/pll_60mhz.v ../hba_system.v ../../../serial_fpga/serial_fpga.v ../../../serial_fpga/send_recv.v ../../../common/uart.v ../../../common/hba_master.v ../../../common/hba_arbiter.v ../../../common/hba_or_masters.v ../../../common/hba_or_slaves.v ../../../hba_reg_bank/hba_reg_bank.v ../../../hba_sonar/hba_sonar.v ../../../hba_sonar/sr04.v ../../../hba_basicio/hba_basicio.v ../../../hba_gpio/hba_gpio.v

PIN_DEF = ../../../boards/$(BOARD)/pins.pcf

all: $(PROJ).rpt $(PROJ).bin

%.blif: $(SOURCES)
	yosys -p 'synth_ice40 -top $(PROJ) -blif $@' $^

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d $(subst hx,,$(subst lp,,$(DEVICE))) -o $@ -p $^

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
