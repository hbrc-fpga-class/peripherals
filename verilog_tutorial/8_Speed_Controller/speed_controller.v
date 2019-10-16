// Force error when implicit net has no type.
`default_nettype none

module speed_controller
(
    input wire clk,
    input wire reset,
    input wire en,

    input wire [7:0] actual_speed,
    input wire [7:0] desired_speed,

    input wire [7:0] init_pwm,

    output wire [7:0] pwm_value
);

/*
**********************
*  Signals
**********************
*/

wire speed_too_slow;
wire speed_too_fast;
wire slowing;
wire speeding_up;

reg [7:0] previous_speed;

wire up = speed_too_slow & ~speeding_up;
wire down = speed_too_fast & ~slowing;

reg [7:0] init_pwm_reg;
reg load;

/*
**********************
*  Instantiations
**********************
*/

// Compare actual speed to desired speed
comparator comp_inst1
(
    .clk(clk),
    .reset(reset),
    .en(en),
    .in1(actual_speed),  // [7:0]
    .in2(desired_speed),  // [7:0]

    .less_than(speed_too_slow),       // in1 < in2
    //.equal(),           // in1 = in2
    .greater_than(speed_too_fast)     // in1 > in2
);

// Check if we are accel or decel
comparator comp_inst2
(
    .clk(clk),
    .reset(reset),
    .en(en),
    .in1(actual_speed),  // [7:0]
    .in2(previous_speed),  // [7:0]

    .less_than(slowing),       // in1 < in2
    //.equal(),           // in1 = in2
    .greater_than(speeding_up)     // in1 > in2
);

up_down_counter up_down_counter_inst
(
    .clk(clk),
    .reset(reset),
    .en(en),
    .load(load),

    .init_value(init_pwm_reg),   // [7:0]
    .up(up),
    .down(down),

    .out_value(pwm_value) // [7:0]
);

/*
**********************
*  Main
**********************
*/

// Remember previous speed
always @ (posedge clk)
begin
    if (reset) begin
        previous_speed <= 0;
    end else begin
        if (en) begin
            previous_speed <= actual_speed;
        end
    end
end

// Generate load for init_pwm
always @ (posedge clk)
begin
    if (reset) begin
        init_pwm_reg <= 0;
        load <= 0;
    end else begin
        init_pwm_reg <= init_pwm;
        load <= 0;
        if (init_pwm_reg != init_pwm) begin
            // new init_pwm value, so load it
            load <= 1;
        end
    end
end


endmodule

