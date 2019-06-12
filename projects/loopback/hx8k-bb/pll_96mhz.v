/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:   96.000 MHz
 * Achieved output frequency:    96.000 MHz
 */

module pll_96mhz(
	input  wire clock_in,
`ifdef TESTBENCH
	output reg clock_out,
	output reg locked
`else
	output wire clock_out,
	output wire locked
`endif
	);

`ifdef TESTBENCH
initial begin
    clock_out = 0;
    locked = 1;
end

// Generate a 96mhz clock
always begin
    #5.2 clock_out <= ~clock_out;
end

`else

wire clock_internal;

SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b0111111),	// DIVF = 63
		.DIVQ(3'b011),		// DIVQ =  3
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clock_in),
		.PLLOUTCORE(clock_internal)
		);

SB_GB clk_gb ( .USER_SIGNAL_TO_GLOBAL_BUFFER(clock_internal)		
                  , .GLOBAL_BUFFER_OUTPUT(clock_out) );

`endif

endmodule
