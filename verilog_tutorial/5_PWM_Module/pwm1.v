// Drive Left Motor with 100khz pwm at 20% duty cycle.

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
localparam PWM_FREQUENCY = 160_000;
localparam PERIOD_COUNT = (CLK_FREQUENCY/PWM_FREQUENCY);
localparam COUNT_BITS = $clog2(PERIOD_COUNT);
localparam DUTY_CYCLE = 20;


// Assignments
assign dir = ~button0;      // Button0 controls direction
assign float_n = button1;   // Button1 enables float
assign led = {6'h0,float_n,dir}; // Turn off leds

// Signals
reg [COUNT_BITS-1:0] pwm_count;

// Generate PWM
initial begin
    // added for sim
    pwm<=0; 
    pwm_count<=0;
    $display("PERIOD_COUNT: ",PERIOD_COUNT);
    $display("COUNT_BITS: ",COUNT_BITS);
end
always @ (posedge clk_16mhz)
begin
    pwm_count <= pwm_count + 1;
    pwm <= 1;
    if (pwm_count >= DUTY_CYCLE) begin
        pwm <= 0;
    end
    if (pwm_count == PERIOD_COUNT) begin
        pwm_count <= 0;
    end
end

endmodule

