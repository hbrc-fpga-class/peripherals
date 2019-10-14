/*
*****************************
* MODULE : pulse_counter.v
*
* This module counts pulses using a 16-bit register.
* It uses the dir_in to determine if it should
* count up or down. Can be used to count encoder ticks.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/29/2019
*
*****************************
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

module pulse_counter #
(
    parameter integer FWD = 1
)
(
    input wire clk,
    input wire reset,
    input wire en,

    input wire pulse_in,
    input wire dir_in,

    input wire speed_interval_pulse,
    output reg [7:0] speed_count,   // count between speed interval pulses

    output reg [15:0] count,
    output reg valid
);

/*
********************************************
* Signals
********************************************
*/


// Register the pulse_in to find edges
reg pulse_in_reg;

wire posedge_pulse_in;
assign posedge_pulse_in = (pulse_in==1) && (pulse_in_reg==0);

reg [7:0] tmp_speed_count;

/*
********************************************
* Signals
********************************************
*/

always @ (posedge clk)
begin
    if (reset) begin
        pulse_in_reg <= 0;
    end else begin
        pulse_in_reg <= pulse_in;
    end
end

always @ (posedge clk)
begin
    if (reset) begin
        count <= 0;
        speed_count <= 0;
        tmp_speed_count <= 0;
        valid <= 1;
    end else begin
        valid <= 0;
        // update count on rising edge
        if (posedge_pulse_in) begin
            count <= (dir_in == FWD) ? (count + 1) : (count - 1);
            tmp_speed_count <= (dir_in == FWD) ? (tmp_speed_count + 1) : (tmp_speed_count - 1);
            // Deassert en to avoid peripheral reg updates during read.
            if (en) begin
                valid <= 1;
            end
        end
        if (speed_interval_pulse) begin
            speed_count <= tmp_speed_count;
            tmp_speed_count <= 0;
        end
    end
end

endmodule

