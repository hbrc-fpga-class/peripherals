// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps


module timer_pulse_tb;

// Parameters
parameter integer CLK_FREQUENCY = 50_000_000;

// Inputs (registers)
reg clk;
reg reset;
reg [7:0] rate_ms;

// Output (wires)
wire pulse;

// Instantiate DUT (device under test)
timer_pulse #
(
    .CLK_FREQUENCY(CLK_FREQUENCY)
) timer_pulse_inst
(
    .clk(clk),
    .reset(reset),
    .rate_ms(rate_ms),    // [7:0]

    .pulse(pulse)
);

// Main testbench code
initial begin
    $dumpfile("timer_pulse.vcd");
    $dumpvars(0, timer_pulse_tb);

    // init inputs
    clk = 0;
    reset = 0;
    rate_ms = 10;   // .01 sec

    // Wait 19ns 
    #19;
    reset = 1;

    // Wait 19ns 
    #19;
    reset = 0;

    // Wait .030 seconds
    #30000000;

    // end simulation
    $display("done: ",$realtime);
    $finish;
end

// Generate a 50mhz clk
always begin
    #10 clk = ~clk;
end

endmodule

