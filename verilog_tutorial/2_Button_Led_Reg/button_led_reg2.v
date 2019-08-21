/* Buttons connected to leds via combinatorial path. */

// Force error when implicit net has no type.
`default_nettype none

module button_led_reg2
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led
);


always @ (*)
begin
    led[0] <= ~button0;
    led[1] <= ~button1;
    led[7:2] <= 0;
end

endmodule
