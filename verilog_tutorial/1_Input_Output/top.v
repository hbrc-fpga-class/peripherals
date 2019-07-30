/* 0_Input_Output.  Button directly to led. */

// Force error when implicit net has no type.
`default_nettype none

module top
(
    input wire button0,
    input wire button1,
    output wire [7:0] led
);

assign led[0] = ~button0;
assign led[1] = ~button1;

assign led[7:2] = 0;

endmodule
