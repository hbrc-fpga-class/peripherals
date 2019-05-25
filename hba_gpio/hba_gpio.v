/*
*****************************
* MODULE : hba_gpio.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It provides an interface to control 4 GPIO pins.
* There are three registers:
*
* reg0: Pins Register.  This register is used to read or write
*       the value of the pins.
* reg1: Direction Register. This register specifies each pin
*       as an input or an output.  1=output, 0=input.
* reg2: Interrupt Register.  This register is an interrupt enable mask.
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
// `default_nettype none

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

    output reg [DBUS_WIDTH-1:0] gpio_dbus,   // The output data bus.
    output reg gpio_xferack,     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    output wire gpio_interrupt,   // Send interrupt back

    // hba_gpio pins
    output wire [3:0] gpio_out_en,
    output wire [3:0] gpio_out_sig,
    input wire [3:0] gpio_in_sig
);

/*
*****************************
* Signals and Assignments
*****************************
*/

reg [3:0] pin_interrupt;

wire [PERIPH_ADDR_WIDTH-1:0] periph_addr = 
    hba_abus[ADDR_WIDTH-1:ADDR_WIDTH-PERIPH_ADDR_WIDTH];

// logic to decode addresses
wire addr_decode_hit = (periph_addr == PERIPH_ADDR);
wire addr_hit_clear = ~hba_select | gpio_xferack;

// Or all pin-interrupt bits together
assign gpio_interrupt = |pin_interrupt;

reg addr_hit;

// Define the bank of registers
reg [DBUS_WIDTH-1:0] reg0;  // Pins Register
reg [DBUS_WIDTH-1:0] reg1;  // Dir Register
reg [DBUS_WIDTH-1:0] reg2;  // Interupt Enable Register

reg [DBUS_WIDTH-1:0] reg0_prev; // Previous Pins Register

localparam INPUT = 0;
localparam OUPUT = 1;

// Output is the value of the register.
// Valid when gpio_out_en is asserted.
assign gpio_out_sig = reg0;

// gpio_out_en is the direction register
assign gpio_out_en = reg2;


/*
*****************************
* Main
*****************************
*/

// Generate addr_hit
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        addr_hit <= 0;
    end else begin
        if (addr_hit_clear)
            addr_hit <= 0;
        else
            addr_hit <= addr_decode_hit;
    end
end

// Read/Write Register's state machine
reg [7:0] gpio_state;

// Define states
localparam IDLE   = 0;
localparam READ   = 1;
localparam WRITE  = 2;
localparam WAIT   = 3;

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        gpio_state <= IDLE;
        gpio_xferack <= 0;
        gpio_dbus <= 0;
        reg0 <= 0;
        reg1 <= 0;
        reg2 <= 0;
    end else begin

        // For inputs read from gpio_in_sig
        if (gpio_out_en[0] == 0) begin
            reg0[0] <= gpio_in_sig[0];
        end
        if (gpio_out_en[1] == 0) begin
            reg0[1] <= gpio_in_sig[1];
        end
        if (gpio_out_en[2] == 0) begin
            reg0[2] <= gpio_in_sig[2];
        end
        if (gpio_out_en[3] == 0) begin
            reg0[3] <= gpio_in_sig[3];
        end

        case (gpio_state)
            IDLE : begin
                gpio_xferack <= 0;
                gpio_dbus <= 0;

                if (addr_hit)
                begin
                    if (hba_rnw)
                        gpio_state <= READ;
                    else
                        gpio_state <= WRITE;
                end
            end
            READ : begin
                gpio_xferack <= 1;
                gpio_state <= WAIT;
                case(hba_abus[REG_ADDR_WIDTH-1:0])
                    0 : begin
                        gpio_dbus <= reg0;
                    end
                    1 : begin
                        gpio_dbus <= reg1;
                    end
                    2 : begin
                        gpio_dbus <= reg2;
                    end
                    default : begin
                        gpio_dbus <= 0;
                    end
                endcase
            end
            WRITE : begin
                gpio_xferack <= 1;
                gpio_state <= WAIT;
                case(hba_abus[REG_ADDR_WIDTH-1:0])
                    0 : begin
                        reg0 <= hba_dbus;
                    end
                    1 : begin
                        reg1 <= hba_dbus;
                    end
                    2 : begin
                        reg2 <= hba_dbus;
                    end
                    default : ; // Do Nothing
                endcase
            end
            WAIT : begin
                gpio_state <= IDLE;
                gpio_xferack <= 0;
                gpio_dbus <= 0;
            end
            default begin
                gpio_state <= IDLE;
                gpio_xferack <= 0;
                gpio_dbus <= 0;
            end
        endcase
    end
end

// Generate Pin Interrupts
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        reg0_prev <= 0;
        pin_interrupt <= 0;
    end else begin
        // by default clear the pin interrupts
        pin_interrupt <= 0;

        // Compare pins current state to prev state.
        // To see if need to generate an interrupt.
        pin_interrupt[0] <= reg0[0] != reg0_prev[0];
        pin_interrupt[1] <= reg0[1] != reg0_prev[1];
        pin_interrupt[2] <= reg0[2] != reg0_prev[2];
        pin_interrupt[3] <= reg0[3] != reg0_prev[3];

        // remember the current state of the pins.
        reg0_prev <= reg0;
    end
end

endmodule

