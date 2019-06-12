/*
********************************************
* MODULE top.v
*
* This project implements the serial_fpga master connected
* to one hba_basicio slave.  It is used to test
* that we can write to the leds and read from the buttons.
*
* Target Board: hx8k-bb
*
* Author: Brandon Blodget
* Create Date: 06/11/2019
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

module top
(
    input wire  CLK_12MHZ,

    // serial_fpga pins
    input wire  RXD,  // rxd
    output wire TXD,  // txd
    output wire J2_4, // intr

    // hba_basicio pins
    input wire J2_6,   // basicio_button[0]
    input wire J2_10,  // basicio_button[1]

    output wire [7:0] LED     // basicio_led
);

// Parameters
parameter integer CLK_FREQUENCY = 50_250_000;
parameter integer BAUD = 32'd115_200;

parameter integer DBUS_WIDTH = 8;
parameter integer PERIPH_ADDR_WIDTH = 4;
parameter integer REG_ADDR_WIDTH = 8;

/*
********************************************
* Signals
********************************************
*/

wire clk;
wire locked;
wire rxd;
wire txd;
wire intr;

// hba_basicio pins
wire [7:0] basicio_led;
wire [7:0] basicio_button;

reg reset = 0;
reg [7:0] count = 0;

assign rxd = RXD;
assign TXD = txd;
assign J2_4 = intr;
assign basicio_button[0] = J2_6;
assign basicio_button[1] = J2_10;
assign basicio_button[7:2] = 0;
assign LED = basicio_led;

/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 50mhz clock
pll_50mhz pll_50mhz_inst (
    .clock_in(CLK_12MHZ),
    .clock_out(clk),
    .locked(locked)
);


basicio_test # 
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .BAUD(BAUD),
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
) basicio_test_inst
(
    .clk(clk),
    .reset(reset),
    .rxd(rxd),
    .txd(txd),
    .intr(intr),
    .basicio_led(basicio_led),
    .basicio_button(basicio_button)
);

/*
****************************
* Main
****************************
*/

// Hold reset on power up then release.
// ice40 sets all registers to zero on power up.
// Holding reset will set to default values.
always @ (posedge clk)
begin
    if (count < 10) begin
        reset <= 1;
        count <= count + 1;
    end else begin
        reset <= 0;
    end
end

endmodule

