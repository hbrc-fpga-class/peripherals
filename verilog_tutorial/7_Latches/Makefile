PROJ = latch
DEVICE = lp8k
SOURCES = $(PROJ).v
PIN_DEF = pins.pcf

latch1: $(PROJ)1.rpt $(PROJ)1.bin $(PROJ)1.prog

latch2: $(PROJ)2.rpt $(PROJ)2.bin $(PROJ)2.prog

latch3: $(PROJ)3.rpt $(PROJ)3.bin $(PROJ)3.prog

png: png1 png2 png3

png1: $(PROJ)1.png

png2: $(PROJ)2.png

png3: $(PROJ)3.png


%.blif: %.v
	yosys -p 'synth_ice40 -top $* -blif $@' $^

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

%.prog: %.bin
	prog_fpga.py $<


clean:
	rm -f a.out *.blif *.asc *.rpt *.bin *.png *.dot

.SECONDARY:
.PHONY: latch1 latch2 latch3 png png1 png2 png3 clean
