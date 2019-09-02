// Force error when implicit net has no type.
`default_nettype none

module pwm1
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led,

    // Motor pins
    output wire pwm,
    output wire dir,
    output wire float_n
);


endmodule

