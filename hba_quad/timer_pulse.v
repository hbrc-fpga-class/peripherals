/*
*****************************
* MODULE : timer_pulse
*
* This module generates a one clock pulse
* at a frequency specified by the input rate_ms.
* Valid range is 1 .. 255 ms.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 10/13/2019
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


module timer_pulse #
(
    parameter integer CLK_FREQUENCY = 50_000_000
)
(
    input wire clk,
    input wire reset,
    input wire [7:0] rate_ms,

    output reg pulse
);


// Generate the interrupt enable at specified rate
localparam ONE_MS_COUNT = ( CLK_FREQUENCY / 1000 );
localparam COUNT_BITS = $clog2(ONE_MS_COUNT);
reg [COUNT_BITS-1:0] count_to_1ms;
reg [7:0] count_1ms;
always @ (posedge clk)
begin
    if (reset) begin
        count_to_1ms <= 0;
        count_1ms <= 0;
        pulse <= 0;
    end else begin
        if (rate_ms != 0) begin
            pulse <= 0;
            count_to_1ms <= count_to_1ms + 1;
            if (count_to_1ms == (ONE_MS_COUNT-1)) begin
                count_to_1ms <= 0;
                count_1ms <= count_1ms + 1;
            end
            if (count_1ms == rate_ms) begin
                count_1ms <= 0;
                pulse <= 1;
            end
        end
    end
end

endmodule


