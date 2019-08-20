/* Count on the leds. */

// Force error when implicit net has no type.
`default_nettype none

module led_counter1
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led
);

// internal registers
reg inc_led;
reg [23:0] fast_count;


// A constant
localparam QUARTER_SEC = 4_000_000;

// Generate a pulse to inc_leds every
// quarter of a second.
always @ (posedge clk_16mhz)
begin
    inc_led <= 0;       // default
    fast_count <= fast_count + 1;
    if (fast_count == QUARTER_SEC) begin
        inc_led <= 1;
        fast_count <= 0;
    end
end

// Increment the led count.
always @ (posedge clk_16mhz)
begin
    if (inc_led) begin
        led <= led + 1;
    end
end

endmodule
