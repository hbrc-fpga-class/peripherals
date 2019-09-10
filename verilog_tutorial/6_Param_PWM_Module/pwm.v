// Force error when implicit net has no type.
`default_nettype none

module pwm #
(
    parameter CLK_FREQUENCY = 16_000_000,
    parameter PWM_FREQUENCY = 160_000,
    parameter PERIOD_COUNT = (CLK_FREQUENCY/PWM_FREQUENCY),
    parameter COUNT_BITS = $clog2(PERIOD_COUNT),
    parameter DUTY_CYCLE = 20
)
(
    input wire clk_16mhz,
    input wire dir_ctrl,
    input wire float_ctrl,

    // Motor pins
    output reg pwm,
    output wire dir,
    output wire float_n
);

// Assignments
assign dir = ~dir_ctrl;      // controls direction
assign float_n = float_ctrl;   // enables float

// Signals
reg [COUNT_BITS-1:0] pwm_count;

// Generate PWM
always @ (posedge clk_16mhz)
begin
    pwm_count <= pwm_count + 1;
    pwm <= 1;
    if (pwm_count >= DUTY_CYCLE) begin
        pwm <= 0;
    end
    if (pwm_count == (PERIOD_COUNT-1)) begin
        pwm_count <= 0;
    end
end

endmodule

