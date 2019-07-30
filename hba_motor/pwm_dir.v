/*
********************************************
* MODULE pwm_dir.v
*
* This module generates a 100khz pwm pulse
* with a variable pulse width.  It also controls
* a direction bit. It is used to generate signals
* for a motor driver IC such as the TI DRV8838.
*
* Author: Brandon Blodget
* Create Date: 06/21/2019
*
********************************************
*/

/*
*****************************
*
* Copyright (C) 2019 by Brandon Blodget <brandon.blodget@gmail.com>
* All rights reserved.
*
* License:
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

module pmw_dir # 
(
    parameter integer CLK_FREQUENCY = 60_000_000,
    parameter integer PWM_FREQUENCY = 100_000,
    parameter integer PERIOD_COUNT = (CLK_FREQUENCY / PWM_FREQUENCY),
    parameter integer DUTY_1_PERCENT = (PERIOD_COUNT / 100)
)
(
    input wire clk,
    input wire reset,
    input wire en,
    input wire float,
    input wire [6:0] duty_cycle,
    input wire dir_in,

    output reg pwm,
    output reg dir_out,
    output wire float_n
);

/*
********************************************
* Assignments
********************************************
*/

assign float_n = ~float;


/*
********************************************
* Main
********************************************
*/


// Generate the 100khz pulse

// Max count is 1023
// Needs to be greater than PERIOD_COUNT
reg [9:0] pulse_100k_count;

// Asserted for 1 clock cycle every 10us.
reg pulse_100k;

always @ (posedge clk)
begin
    if (reset) begin
        pulse_100k_count <= 0;
        pulse_100k <= 0;
    end else begin
        pulse_100k <= 0;    // default
        if (en) begin
            pulse_100k_count <= pulse_100k_count + 1;
            if (pulse_100k_count == (PERIOD_COUNT-1)) begin
                pulse_100k_count <= 0;
                pulse_100k <= 1;
            end
        end
    end
end

// Generate pulse width
localparam FORWARD = 0;
localparam REVERSE = 1;

// Max count is 255
// Needs to be greater than DUTY_1_PERCENT
reg [7:0] pwm_count;

// Track how much of the duty cycle has been completed
// Compared against duty_cycle[6:0] reg
reg [7:0] duty_amount;

always @ (posedge clk)
begin
    if (reset) begin
        pwm <= 0;
        dir_out <= FORWARD;
        pwm_count <= 0;
        duty_amount <= 0;
    end else begin
        if (en) begin
            //  Pass through the direction bit
            dir_out <= dir_in;

            // Start pwm on 100k start pulse
            if (pulse_100k) begin
                pwm_count <= 0;
                duty_amount <= 0;
                if (duty_cycle == 0) begin
                    pwm <= 0;
                end else begin
                    pwm <= 1;
                end
            end

            // Pwm active for specified duty_count
            if (pwm && (duty_cycle<100)) begin
                pwm_count <= pwm_count + 1;
                if (duty_amount == duty_cycle) begin
                    pwm <= 0;
                end else if (pwm_count == (DUTY_1_PERCENT-1)) begin
                    pwm_count <= 0;
                    duty_amount <= duty_amount + 1;
                end
            end

        end else begin
            // Brake by set pwm to zero
            pwm <= 0;
            dir_out <= FORWARD;
            pwm_count <= 0;
            duty_amount <= 0;
        end
    end
end

endmodule

