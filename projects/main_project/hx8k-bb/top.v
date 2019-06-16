/*
********************************************
* MODULE top.v
*
* This is a top level file for the hba_system module.
* It contains the board specific interfaces and
* instantiates the hba_system.
*
* Target Board: hx8k-bb
*
* Author: Brandon Blodget
* Create Date: 06/15/2019
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

    // serial_fpga pins (SLOT 0)
    input wire  RXD,  // rxd
    output wire TXD,  // txd
    output wire J2_4, // intr

    // hba_basicio pins (SLOT 1)
    input wire J2_18,       // basicio_button[0]
    input wire J2_20,       // basicio_button[1]
    output wire [7:0] LED,  // basicio_led

    // hba_gpio pins (SLOT 2)
    inout wire J2_22,   // gpio_port[0]
    inout wire J2_26,   // gpio_port[1]
    inout wire J2_28,   // gpio_port[2]
    inout wire J2_30,   // gpio_port[3]

    // hba_sonar pins (SLOT 3)
    output wire J2_6,   // sonar_trig[0]
    input  wire J2_10,  // sonar_echo[0]
    output wire J2_12,  // sonar_trig[1]
    input  wire J2_14   // sonar_echo[1]

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
assign basicio_button[0] = J2_18;
assign basicio_button[1] = J2_20;
assign basicio_button[7:2] = 0;
assign LED = basicio_led;


// hba_sonar pins
wire [1:0] sonar_trig;
wire [1:0] sonar_echo;

assign J2_6 = sonar_trig[0];
assign sonar_echo[0] = J2_10;
assign J2_12 = sonar_trig[1];
assign sonar_echo[1] = J2_14;

// hba_gpio wires
wire [3:0] slot2_gpio_out_en;
wire [3:0] slot2_gpio_out_sig;
wire [3:0] slot2_gpio_in_sig;

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


hba_system # 
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .BAUD(BAUD),
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
) hba_system_inst
(
    .clk(clk),
    .reset(reset),

    // SLOT(0) : serial_fpga pins
    .rxd(rxd),
    .txd(txd),
    .intr(intr),

    // SLOT(1) : hba_basicio pins
    .basicio_led(basicio_led),
    .basicio_button(basicio_button),

    // SLOT(2) : hba_gpio pins
    .gpio_out_en(slot2_gpio_out_en),
    .gpio_out_sig(slot2_gpio_out_sig),
    .gpio_in_sig(slot2_gpio_in_sig),

    // SLOT(3) : hba_sonar pins
    .sonar_trig(sonar_trig),
    .sonar_echo(sonar_echo)
);

// SLOT2: GPIO_PORT bit 0
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_gpio_port0_inst  (
    .PACKAGE_PIN(J2_22),
    .OUTPUT_ENABLE(slot2_gpio_out_en[0]),
    .D_OUT_0(slot2_gpio_out_sig[0]),
    .D_IN_0(slot2_gpio_in_sig[0])
);

// SLOT2: GPIO_PORT bit 1
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_gpio_port1_inst  (
    .PACKAGE_PIN(J2_26),
    .OUTPUT_ENABLE(slot2_gpio_out_en[1]),
    .D_OUT_0(slot2_gpio_out_sig[1]),
    .D_IN_0(slot2_gpio_in_sig[1])
);

// SLOT2: GPIO_PORT bit 2
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_gpio_port2_inst  (
    .PACKAGE_PIN(J2_28),
    .OUTPUT_ENABLE(slot2_gpio_out_en[2]),
    .D_OUT_0(slot2_gpio_out_sig[2]),
    .D_IN_0(slot2_gpio_in_sig[2])
);

// SLOT2: GPIO_PORT bit 3
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_gpio_port3_inst  (
    .PACKAGE_PIN(J2_30),
    .OUTPUT_ENABLE(slot2_gpio_out_en[3]),
    .D_OUT_0(slot2_gpio_out_sig[3]),
    .D_IN_0(slot2_gpio_in_sig[3])
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

