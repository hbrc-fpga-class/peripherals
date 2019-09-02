// Force error when implicit net has no type.
`default_nettype none

module pwm1
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output wire [7:0] led,

    // Motor pins
    output reg pwm,
    output wire dir,
    output wire float_n
);

// Parameters
localparam CLK_FREQUENCY = 16_000_000;
localparam PWM_FREQUENCY = 100_000;
localparam PERIOD_COUNT = (CLK_FREQUENCY/PWM_FREQUENCY);
localparam COUNT_BITS = $clog2(PERIOD_COUNT);
localparam DUTY_1_PERCENT = (PERIOD_COUNT/100);
localparam DUTY_CYCLE = 20;
localparam ON_COUNT = (DUTY_CYCLE*DUTY_1_PERCENT);

// Assignments
assign dir = ~button0;      // Button0 controls direction
assign float_n = button1;   // Button1 enables float
assign led = {6'h0,float_n,dir}; // Turn off leds

// Signals
reg [COUNT_BITS-1:0] pwm_count;

// Generate PWM
initial pwm<=0; // added for sim
always @ (posedge clk_16mhz)
begin
    pwm_count <= pwm_count + 1;
    pwm <= 1;
    if (pwm_count >= ON_COUNT) begin
        pwm <= 0;
    end
    if (pwm_count == PERIOD_COUNT) begin
        pwm_count <= 0;
    end
end

endmodule

