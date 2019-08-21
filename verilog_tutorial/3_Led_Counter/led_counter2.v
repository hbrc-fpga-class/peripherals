/* Add reset, catch button edge. */

// Force error when implicit net has no type.
`default_nettype none

module led_counter2
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led
);

// reset when button0 is pushed
wire reset = ~button0;

// internal registers
reg inc_led;
reg [23:0] fast_count;
reg count_dir;
reg [3:0] button1_reg;


// Constants
localparam QUARTER_SEC  = 4_000_000;
localparam COUNT_UP     = 0;
localparam COUNT_DOWN   = 1;

// Generate a pulse to inc_leds every
// quarter of a second.
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        inc_led <= 0;
        fast_count <= 0;
    end else begin
        inc_led <= 0;       // default
        fast_count <= fast_count + 1;
        if (fast_count == QUARTER_SEC) begin
            inc_led <= 1;
            fast_count <= 0;
        end
    end
end

// Rising edge on button1, switches count direction.
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        count_dir <= COUNT_UP;
        button1_reg <= 0;
    end else begin
        button1_reg[3:0] <= {button1_reg[2:0], ~button1};
        if (button1_reg == 4'b0001) begin
            count_dir <= ~count_dir;
        end
    end
end

// Increment the led count.
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        led <= 0;
    end else begin
        if (inc_led) begin
            if (count_dir == COUNT_UP) begin
                led <= led + 1;
            end else begin
                led <= led - 1;
            end
        end
    end
end

endmodule
