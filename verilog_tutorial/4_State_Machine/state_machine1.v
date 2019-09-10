/* Light pattern leds */
/* State machine version. */

// Force error when implicit net has no type.
`default_nettype none

module state_machine1
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg [7:0] led
);

// reset when button0 is pushed
wire reset = ~button0;

// button1 is an enable
wire en = button1;

// internal registers
reg inc_led;
reg [23:0] fast_count;
reg count_dir;
reg [2:0] shift_count;

// State machine register
reg [2:0] state;

// Constants
localparam DELAY_COUNT  = 1_500_000;
localparam COUNT_UP     = 0;
localparam COUNT_DOWN   = 1;

// State machine states
localparam STATE0  = 0;
localparam STATE1  = 1;
localparam STATE2  = 2;
localparam STATE3  = 3;
localparam STATE4  = 4;
localparam STATE5  = 5;
localparam STATE6  = 6;
localparam STATE7  = 7;

// Generate a pulse to inc_leds every
// quarter of a second.
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        inc_led <= 0;
        fast_count <= 0;
    end else begin
        if (en) begin
            inc_led <= 0;       // default
            fast_count <= fast_count + 1;
            if (fast_count == DELAY_COUNT) begin
                inc_led <= 1;
                fast_count <= 0;
            end
        end
    end
end


// state machine logic
always @ (posedge clk_16mhz)
begin
    if (reset) begin
        state <= STATE0;
        led <= 0;
    end else begin
        case (state)
            STATE0 : begin
                led <= 8'b1100_0011;
                if (inc_led) begin
                    state <= STATE1;
                end
            end
            STATE1 : begin
                led <= 8'b0110_0110;
                if (inc_led) begin
                    state <= STATE2;
                end
            end
            STATE2 : begin
                led <= 8'b0011_1100;
                if (inc_led) begin
                    state <= STATE3;
                end
            end
            STATE3 : begin
                led <= 8'b0001_1000;
                if (inc_led) begin
                    state <= STATE4;
                end
            end
            STATE4 : begin
                led <= 8'b0000_0000;
                if (inc_led) begin
                    state <= STATE5;
                end
            end
            STATE5 : begin
                led <= 8'b0001_1000;
                if (inc_led) begin
                    state <= STATE6;
                end
            end
            STATE6 : begin
                led <= 8'b0011_1100;
                if (inc_led) begin
                    state <= STATE7;
                end
            end
            STATE7 : begin
                led <= 8'b0110_0110;
                if (inc_led) begin
                    state <= STATE0;
                end
            end
            default : begin
                state <= STATE0;
                led <= 0;
            end
        endcase
    end
end

endmodule
