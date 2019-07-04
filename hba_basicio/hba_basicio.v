/*
*****************************
* MODULE : hba_basicio.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It provides an interface to control some "Basic IO".
* The Basic IO items are:
* - 8 LEDs
* - 8 Buttons
* 
* NOTE : A given board may not have 8 leds
* or 8 buttons, so the parent module may tie these
* off as appropriate. 
* 
* Register Interface
* 
* There are three 8-bit registers.
* 
* __reg0__ : The value to write to the LEDs.
* __reg1__ : The button value.
* __reg2__ : Interrupt Enable Register. A value of 1 indicates that
* change in button state will cause an interrupt.
*
* See the README.md in this directory for more information.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/11/2019
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

module hba_basicio #
(
    // Defaults
    // DBUS_WIDTH = 8
    // ADDR_WIDTH = 12
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH,
    parameter integer PERIPH_ADDR = 0
)
(
    // HBA Bus Slave Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire hba_rnw,         // 1=Read from register. 0=Write to register.
    input wire hba_select,      // Transfer in progress.
    input wire [ADDR_WIDTH-1:0] hba_abus, // The input address bus.
    input wire [DBUS_WIDTH-1:0] hba_dbus,  // The input data bus.

    output wire [DBUS_WIDTH-1:0] hba_dbus_slave,   // The output data bus.
    output wire hba_xferack_slave,     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    output reg slave_interrupt,   // Send interrupt back

    // hba_basicio pins
    output wire [7:0] basicio_led,
    input wire [7:0] basicio_button
);

/*
*****************************
* Signals and Assignments
*****************************
*/

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_led;      // reg0: Led reigser
wire [DBUS_WIDTH-1:0] reg_intr_en;  // reg2: Interrupt Enable Register
reg [DBUS_WIDTH-1:0] reg_button_in;  // reg1: button value

reg slv_wr_en;

assign basicio_led = reg_led;

/*
*****************************
* Instantiation
*****************************
*/

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(PERIPH_ADDR)
) hba_reg_bank_inst
(
    // HBA Bus Slave Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.

    // Access to registgers
    .slv_reg0(reg_led),
    // XXX .slv_reg1(),
    .slv_reg2(reg_intr_en),
    
    // writeable registers
    // XXX .slv_reg0_in(),
    .slv_reg1_in(reg_button_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0010),    // 0010, means reg1 is writeable.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);


/*
*****************************
* Main
*****************************
*/

// Register the button inputs
reg [DBUS_WIDTH-1:0] reg_button_in2;
reg [DBUS_WIDTH-1:0] reg_old_led0;
reg [DBUS_WIDTH-1:0] reg_old_led1;
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        reg_button_in <= 0;
        reg_button_in2 <= 0;
        slv_wr_en <= 0;
        slave_interrupt <= 0;
    end else begin
        // Defaults
        slv_wr_en <= 0;     // default
        slave_interrupt <= 0;

        // reg latest and last
        reg_button_in <= basicio_button;
        reg_button_in2 <= reg_button_in;

        // Check for a button change
        if (reg_button_in != reg_button_in2) begin
            slv_wr_en <= 1;
            if (reg_intr_en) begin
                slave_interrupt <= 1;
            end
        end

        // Check for an led change
        if (reg_old_led0 != reg_old_led1) begin
            if (reg_intr_en) begin
                slave_interrupt <= 1;
            end
        end
        reg_old_led1 <= reg_old_led0;
        reg_old_led0 <= reg_led;
    end
end

endmodule

