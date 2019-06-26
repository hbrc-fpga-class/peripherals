/*
*****************************
* MODULE : qtr.v
*
* This module provides an interface to the
* QTR reflectance sensor from Pololu.
* It returns an 8-bit value which represents
* The time it took for the QTR output pin to go
* low after being charged.  The higher the reflectance
* the shorter the time for the pin to go low.  The resolution
* of the 8-bit value is in 10us.  S0 max value of
* 255 gives a time of 2.55ms.
    *
* TODO: Add support for CTRL pin, to turn of led, and change
*   brightness levels.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/25/2019
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


module qtr #
(
    parameter integer CLK_FREQUENCY = 60_000_000,
    parameter integer TEN_US_COUNT = ( CLK_FREQUENCY / 100_000 )
)
(
    input wire clk,
    input wire reset,
    input wire en,

    output reg [7:0] value,
    output reg valid,

    // hba_qtr pins
    output reg qtr_out_en,
    output reg qtr_out_sig,
    input wire qtr_in_sig,
    output reg qtr_ctrl

);


/*
********************************************
* Main
********************************************
*/

// Generate 10us pulses
//
reg [9:0] count_10us;
reg reset_count_10us;
reg pulse_10us;

always @ (posedge clk)
begin
    if (reset_count_10us) begin
        count_10us <= 0;
    end else begin
        pulse_10us <= 0;
        count_10us <= count_10us + 1;
        if (count_10us == TEN_US_COUNT) begin
            count_10us <= 0;
            pulse_10us <= 1;
        end
    end
end


// State Machine for QTR measurement
reg [7:0] tmp_value;

// QTR states
reg [1:0] qtr_state;
localparam IDLE         = 0;
localparam CHARGE_10US  = 1;
localparam TIME_QTR     = 2;
localparam DONE         = 3;

always @ (posedge clk)
begin
    if (reset) begin
        qtr_out_en <= 0;
        qtr_out_sig <= 0;
        valid <= 0;
        value <= 0;
        reset_count_10us <= 0;
        tmp_value <= 0;
        qtr_ctrl <= 0;
    end else begin
        case (qtr_state)
            IDLE : begin
                qtr_out_en <= 0;
                qtr_out_sig <= 0;
                valid <= 0;
                reset_count_10us <= 1;
                qtr_ctrl <= 0;  // led off by default
                if (en) begin
                    qtr_state <= CHARGE_10US;
                end
            end
            CHARGE_10US : begin
                qtr_ctrl <= 1;      // turn on the led
                reset_count_10us <= 0;
                qtr_out_en <= 1;
                qtr_out_sig <= 1;
                if (pulse_10us) begin
                    tmp_value <= 0;
                    qtr_state <= TIME_QTR;
                end
            end
            TIME_QTR : begin
                qtr_out_en <= 0;    // switch to input
                qtr_out_sig <= 0;
                if (pulse_10us) begin
                    tmp_value <= tmp_value + 1;
                end

                // Check if the sig has gone low
                // Or if our timer has maxed out (2.55ms)
                if ( (qtr_in_sig == 0) || (tmp_value==255) ) begin
                    value <= tmp_value;
                    valid <= 1;
                    qtr_state <= DONE;
                end

            end
            DONE : begin
                valid <= 0;
                // Wait for signal to go low.
                if (qtr_in_sig == 0) begin
                    qtr_state <= IDLE;
                end
            end
            default : begin
                qtr_state <= IDLE;
            end
        endcase
    end
end

endmodule

