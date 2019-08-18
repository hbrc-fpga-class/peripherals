/* Buttons connected to leds via registers. */

// Force error when implicit net has no type.
`default_nettype none

module button_led_reg1
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led
);


always @ (posedge clk_16mhz)
begin
    led[0] <= ~button0;
    led[1] <= ~button1;
    led[7:2] <= 0;
end

endmodule
