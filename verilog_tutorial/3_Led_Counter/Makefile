PROJ = led_counter
DEVICE = lp8k
PIN_DEF = pins.pcf

led_counter1: $(PROJ)1.rpt $(PROJ)1.bin $(PROJ)1.prog

led_counter2: $(PROJ)2.rpt $(PROJ)2.bin $(PROJ)2.prog

led_counter3: $(PROJ)3.rpt $(PROJ)3.bin $(PROJ)3.prog

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
	rm -f a.out *.blif *.asc *.rpt *.bin

.SECONDARY:
.PHONY: all prog clean
