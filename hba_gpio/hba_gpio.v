/*
*****************************
* MODULE : hba_gpio.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It provides an interface to control 4 GPIO pins.
* There are three registers:
*
* reg0(reg_dir): Direction Register (a.k.a out_en) . This register specifies each pin
*       as an input or an output.  1=output, 0=input.
* reg1(reg_pins): Pins Register.  This register is used to read or write
*       the value of the pins.
* reg2(reg_intr_en): Interrupt Register.  This register is an interrupt enable mask.
*       If an interrupt is enabled for a pin, if the logic level
*       level changes for that pin then an interrupt is asserted.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/19/2019
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

module hba_gpio #
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
    output wire slave_interrupt,   // Send interrupt back

    // hba_gpio pins
    output reg [3:0] gpio_out_en,
    output reg [3:0] gpio_out_sig,
    input wire [3:0] gpio_in_sig
);

/*
*****************************
* Signals and Assignments
*****************************
*/

reg [3:0] pin_interrupt;

// Or all pin-interrupt bits together
assign slave_interrupt = |pin_interrupt;


// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_pins;  // Pins Register
wire [DBUS_WIDTH-1:0] reg_dir;  // Dir Register
wire [DBUS_WIDTH-1:0] reg_intr_en;  // Interupt Enable Register

reg [DBUS_WIDTH-1:0] reg_pins_in;  // Set Pins Register

reg [DBUS_WIDTH-1:0] reg_pins_prev; // Previous Pins Register

// Enables writing to slave registers.
reg slv_wr_en;

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
    .slv_reg0(reg_dir),
    .slv_reg1(reg_pins),
    .slv_reg2(reg_intr_en),

    // writeable registers
    .slv_reg1_in(reg_pins_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0010),    // 0010, means reg_pins(reg1) is writeable. etc
    .slv_autoclr_mask(4'b0000)    // No autoclear
);


/*
*****************************
* Main
*****************************
*/

// Read input pins, and write to reg_pins
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        reg_pins_in <= 0;
        gpio_out_sig <= 0;
        gpio_out_en <= 0;
        slv_wr_en <= 0;
    end else begin

        // Drive tristate signals
        gpio_out_sig[3:0] <= reg_pins[3:0];
        gpio_out_en[3:0] <= reg_dir[3:0];

        // Default values
        reg_pins_in <= reg_pins;
        slv_wr_en <= 0;

        // For inputs read from gpio_in_sig
        if (gpio_out_en[0] == 0) begin
            reg_pins_in[0] <= gpio_in_sig[0];
            slv_wr_en <= 1;
        end
        if (gpio_out_en[1] == 0) begin
            reg_pins_in[1] <= gpio_in_sig[1];
            slv_wr_en <= 1;
        end
        if (gpio_out_en[2] == 0) begin
            reg_pins_in[2] <= gpio_in_sig[2];
            slv_wr_en <= 1;
        end
        if (gpio_out_en[3] == 0) begin
            reg_pins_in[3] <= gpio_in_sig[3];
            slv_wr_en <= 1;
        end

    end
end

// Generate Pin Interrupts
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        reg_pins_prev <= 0;
        pin_interrupt <= 0;
    end else begin
        // by default clear the pin interrupts
        pin_interrupt <= 0;

        // Compare pins current state to prev state.
        // To see if need to generate an interrupt.
        if (reg_intr_en[0]) begin
            pin_interrupt[0] <= reg_pins[0] != reg_pins_prev[0];
        end
        if (reg_intr_en[1]) begin
            pin_interrupt[1] <= reg_pins[1] != reg_pins_prev[1];
        end
        if (reg_intr_en[2]) begin
            pin_interrupt[2] <= reg_pins[2] != reg_pins_prev[2];
        end
        if (reg_intr_en[3]) begin
            pin_interrupt[3] <= reg_pins[3] != reg_pins_prev[3];
        end

        // remember the current state of the pins.
        reg_pins_prev <= reg_pins;
    end
end

endmodule

