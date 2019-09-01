/* Kit car style leds. */
/* No state machine version. */

// Force error when implicit net has no type.
`default_nettype none

module state_machine0
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
reg [2:0] shift_count;


// Constants
localparam QUARTER_SEC  = 1_000_000;
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
        shift_count <= 0;
    end else begin
        if (inc_led) begin
            shift_count <= shift_count + 1;
            if (shift_count == 4) begin
                count_dir <= ~count_dir;
                shift_count <= 0;
            end
        end
    end
end

// Increment the led count.
initial led <= 8'b000_0111;
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        led <= 8'b000_0111;
    end else begin
        if (inc_led) begin
            if (count_dir == COUNT_UP) begin
                led <= led << 1;
            end else begin
                led <= led >> 1;
            end
        end
    end
end

endmodule
