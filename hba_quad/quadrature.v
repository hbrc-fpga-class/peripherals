/*
*****************************
* MODULE : quadrature.v
*
* This module provides an interface to a
* quadrature encoder.  It computes the direction
* of the spinning wheel and outputs the combined
* 4X pulses.
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

module quadrature
(
    input wire clk,
    input wire reset,

    // hba_quad input pins
    input wire quad_enc_a,
    input wire quad_enc_b,

    // quad outputs
    output reg enc_out,
    output reg enc_dir

);


/*
********************************************
* Signals
********************************************
*/

reg [1:0] sample;
reg [1:0] sample_reg;


/*
********************************************
* Main
********************************************
*/

localparam FWD      = 0;
localparam EA       = 0;
localparam EB       = 1;

// Sample inputs and save last value
always @ (posedge clk)
begin
    if (reset) begin
        sample <= 0;
        sample_reg <= 0;
    end else begin
        sample_reg <= sample;
        sample[EA] <= quad_enc_a;
        sample[EB] <= quad_enc_b;
    end
end

/* Quadrature.  Channel A leading, Channel B (FWD, enc_dir=0)
*
*      ____      ____      ____      ____
* A __|    |____|    |____|    |____|    |____
*        ____      ____      ____      ____
* B ____|    |____|    |____|    |____|    |____
* S  0 1  3 2  0 1  3 2  0 1  3 2  0 1  3 2 0 ...
*/

/* Quadrature.  Channel B leading, Channel A (Rev, enc_dir=1)
*        ____      ____      ____      ____
* A ____|    |____|    |____|    |____|    |____
*      ____      ____      ____      ____
* B __|    |____|    |____|    |____|    |____
* S  0 2  3 1  0 2  3 1  0 2  3 1  0 2  3 1 0 ...
*/


// Calculate the rotation direction
// And combined pulse
always @ (posedge clk)
begin
    if (reset) begin
        enc_dir <= FWD;
        enc_out <= 0;
    end else begin
        // XOR enc_a and enc_b, to get x4 pulse
        enc_out <= ^sample;

        // If sample differs from previous sample
        // calculate the wheel direction.
        if (sample != sample_reg) begin
            case (sample)
                0 : begin
                    enc_dir <= sample_reg[EA];
                end
                1 : begin
                    enc_dir <= sample_reg[EA];
                end
                2 : begin
                    enc_dir <= ~sample_reg[EA];
                end
                3 : begin
                    enc_dir <= ~sample_reg[EA];
                end
            endcase
        end
    end
end

endmodule


