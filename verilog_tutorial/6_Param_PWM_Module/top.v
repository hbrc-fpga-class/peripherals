module top
(
    input wire  clk_16mhz,

    // basicio
    input wire [1:0] button,
    output wire [7:0] led,

    // motor pins
    output wire [1:0] pwm,
    output wire [1:0] dir,
    output wire [1:0] float_n
);

localparam LEFT     = 0;
localparam RIGHT    = 1;


assign led = {6'h0,button[1],button[0]}; 

// Instantiate PWM modules

pwm #
(
    .DUTY_CYCLE(20)
) pwm_left
(
    .clk_16mhz(clk_16mhz),
    .dir_ctrl(button[0]),
    .float_ctrl(button[1]),

    // Motor pins
    .pwm(pwm[LEFT]),
    .dir(dir[LEFT]),
    .float_n(float_n[LEFT])
);

pwm #
(
    .DUTY_CYCLE(30)
) pwm_right
(
    .clk_16mhz(clk_16mhz),
    .dir_ctrl(button[1]),
    .float_ctrl(button[0]),

    // Motor pins
    .pwm(pwm[RIGHT]),
    .dir(dir[RIGHT]),
    .float_n(float_n[RIGHT])
);


endmodule


