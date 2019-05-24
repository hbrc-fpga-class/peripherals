/*
********************************************
* MODULE top_inout.v
*
* This is a test of inout ports.
*
* Target Board: TinyFPGA BX
*
* Author: Brandon Blodget
* Create Date: 05/20/2019
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

`timescale 1 ns / 1 ns

// Force error when implicit net has no type.
`default_nettype none


module gpio
(
    input clk,
    input wire out_en,
    input wire in_sig,
    output wire out_sig
);


localparam INPUT = 0;
localparam OUTPUT = 1;

always @ (posedge clk)
begin
    if (out_en == 0) begin
        out_sig <= in_sig;
    end
end

endmodule

module top_inout
(
    input wire  CLK_16MHZ,
    input wire  PIN_1,   // out_en
    input wire  PIN_2,   // in_sig
    inout wire  PIN_3,    // bi-directional pin
    output reg PIN_4,    // out_sig
);

localparam INPUT = 0;
localparam OUTPUT = 1;

wire out_en = PIN_1;
wire in_sig;
reg out_sig;

SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b 0)
) io_block_instance (
    .PACKAGE_PIN(PIN_3),
    .OUTPUT_ENABLE(out_en),
    .D_OUT_0(out_sig),
    .D_IN_0(in_sig)
);

gpio gpio_inst
(
    .clk(CLK_16MHZ),
    .out_en(out_en),
    .in_sig(in_sig),
    .out_sig(out_sig)
);

endmodule

