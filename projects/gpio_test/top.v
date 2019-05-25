/*
********************************************
* MODULE top.v
*
* This project implements the serial_fpga master connected
* to one hba_gpio slave.  It is used to test
* that we can read and write to the hba_gpio slave
* registers from the serial port.
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
// `default_nettype none

module top
(
    input wire  CLK_16MHZ,

    // serial_fpga pins
    input wire  PIN_1,  // rxd
    output wire PIN_2,  // txd

    // hba_gpio pins
    inout wire PIN_3,   // gpio_port[0]
    inout wire PIN_4,   // gpio_port[1]
    inout wire PIN_5,   // gpio_port[2]
    inout wire PIN_6,   // gpio_port[3]


    output wire LED     // pll locked
);

// Parameters
parameter integer CLK_FREQUENCY = 50_000_000;
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
wire [3:0] gpio_port;

reg reset = 0;
reg [7:0] count = 0;

assign rxd = PIN_1;
assign PIN_2 = txd;
assign LED = locked;

// hba_gpio wires
wire [3:0] slot1_gpio_out_en;
wire [3:0] slot1_gpio_out_sig;
wire [3:0] slot1_gpio_in_sig;

/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 50mhz clock
pll_50mhz pll_50mhz_inst (
    .clock_in(CLK_16MHZ),
    .clock_out(clk),
    .locked(locked)
);

// NOTE: The Icestorm tools don't have good support for infering
// tri-states.  So we instantiate them manually.


// Slot 1 GPIO_PORT bit 0
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot1_gpio_port0_inst  (
    .PACKAGE_PIN(PIN_3),
    .OUTPUT_ENABLE(slot1_gpio_out_en[0]),
    .D_OUT_0(slot1_gpio_out_sig[0]),
    .D_IN_0(slot1_gpio_in_sig[0])
);

// Slot 1 GPIO_PORT bit 1
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot1_gpio_port1_inst  (
    .PACKAGE_PIN(PIN_4),
    .OUTPUT_ENABLE(slot1_gpio_out_en[1]),
    .D_OUT_0(slot1_gpio_out_sig[1]),
    .D_IN_0(slot1_gpio_in_sig[1])
);

// Slot 1 GPIO_PORT bit 2
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot1_gpio_port2_inst  (
    .PACKAGE_PIN(PIN_5),
    .OUTPUT_ENABLE(slot1_gpio_out_en[2]),
    .D_OUT_0(slot1_gpio_out_sig[2]),
    .D_IN_0(slot1_gpio_in_sig[2])
);

// Slot 1 GPIO_PORT bit 3
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot1_gpio_port3_inst  (
    .PACKAGE_PIN(PIN_6),
    .OUTPUT_ENABLE(slot1_gpio_out_en[3]),
    .D_OUT_0(slot1_gpio_out_sig[3]),
    .D_IN_0(slot1_gpio_in_sig[3])
);

gpio_test # 
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .BAUD(BAUD),
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
) serial_test_inst (
    .clk(clk),
    .reset(reset),
    .rxd(rxd),
    .txd(txd),
    .gpio_out_en(gpio_out_en),
    .gpio_out_sig(gpio_out_sig),
    .gpio_in_sig(gpio_in_sig)
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

