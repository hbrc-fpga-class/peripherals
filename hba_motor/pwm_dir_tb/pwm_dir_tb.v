/*
*****************************
* MODULE : pwm_dir_tb
*
* Testbench for the pwm_dir module.
*
* Author : Brandon Bloodget
* Create Date : 06/21/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps


module pwm_dir_tb;

/*
*****************************
* Parametsr
*****************************
*/

localparam CLK_FREQUENCY = 60_000_000;
localparam PWM_FREQUENCY = 100_000;
localparam PERIOD_COUNT = (CLK_FREQUENCY / PWM_FREQUENCY);
localparam DUTY_1_PERCENT = (PERIOD_COUNT / 100);


/*
*****************************
* Signals
*****************************
*/

// Inputs (registers)
reg clk;
reg reset;
reg en;
reg float;
reg [6:0] duty_cycle;
reg dir_in;

// Output (wires)
wire pwm;
wire dir_out;
wire float_n;

// local
reg done;

/*
*****************************
* Instantiations
*****************************
*/

pmw_dir # 
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .PWM_FREQUENCY(PWM_FREQUENCY)
) pwm_dir_inst
(
    // inputs
    .clk(clk),
    .reset(reset),
    .en(en),
    .float(float),
    .duty_cycle(duty_cycle),    // [6:0]
    .dir_in(dir_in),

    // outputs
    .pwm(pwm),
    .dir_out(dir_out),
    .float_n(float_n)
);

/*
*****************************
* Main
*****************************
*/

initial begin
    $dumpfile("pwm_dir.vcd");
    $dumpvars(0, pwm_dir_tb);

    clk         = 0;
    reset       = 0;
    en          = 0;
    float       = 0;
    duty_cycle  = 0;
    dir_in      = 0;

    // Wait 100ns
    #100;
    $display("CLK_FREQUENCY: %d",CLK_FREQUENCY);
    $display("PWM_FREQUENCY: %d",PWM_FREQUENCY);
    $display("PERIOD_COUNT: %d",PERIOD_COUNT);
    $display("DUTY_1_PERCENT: %d",DUTY_1_PERCENT);
    // Add stimulus here
    @(posedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    duty_cycle = 50;
    en = 1;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);

    @(posedge done);

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $finish;
end

// Generate a 60mhz clk
always begin
    #8.33 clk = ~clk;
end

// Generate the done signal
reg [9:0] pulse_100k_count;
reg [3:0] loops;
always @ (posedge clk)
begin
    if (reset) begin
        pulse_100k_count <= 0;
        loops <= 0;
        done <= 0;
    end else begin
        pulse_100k_count <= pulse_100k_count + 1;
        if (pulse_100k_count == PERIOD_COUNT) begin
            pulse_100k_count <= 0;
            loops <= loops + 1;
        end
        if (loops == 4) begin
            done <= 1;
        end
    end
end


endmodule

