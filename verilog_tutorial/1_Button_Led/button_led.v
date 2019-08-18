/* Buttons directly connected to led. */

module button_led
(
    input wire button0,
    input wire button1,
    output wire [7:0] led
);

assign led[0] = ~button0;
assign led[1] = ~button1;

assign led[7:2] = 0;

endmodule
