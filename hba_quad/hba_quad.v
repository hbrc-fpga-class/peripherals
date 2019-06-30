/*
*****************************
* MODULE : hba_quad.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* This module provides an interface to two
* quatrature encoders.  This module senses the direction
* and increments or decrements the encoder count as appropriate.
* Each encoder count is a 16-bit value, stored in two
* 8-bit registers.  It is recommended to disable the encoder
* updates before reading the encoder values.  Then re-enable
* encoder updates after the values are read.  The encoder
* counts will still be updated internally only the updating
* to the register bank is disabled.
*
* See the README.md for information about the register interface.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/30/2019
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

module hba_quad #
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

    // hba_quad pins
    input wire [1:0] quad_enc_a,
    input wire [1:0] quad_enc_b
);

/*
*****************************
* Params, Signals and Assignments
*****************************
*/

localparam LEFT     = 0;
localparam RIGHT    = 1;

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_ctrl;  // reg0: Control register

wire [DBUS_WIDTH-1:0] reg_quad0_low_in;  // reg1: Lower 8-bits of quad0
wire [DBUS_WIDTH-1:0] reg_quad0_hi_in;  // reg2: Upper 8-bit of quad0

// Enables writing to slave registers.
wire slv_wr_en;

// Indicates new quadrature data
wire [1:0] quad_valid;

// Enable interrupt bit
wire intr_en = reg_ctrl[2];

assign slave_interrupt = (|quad_valid) & intr_en;
assign slv_wr_en = |quad_valid;

wire quad0_en;
assign quad0_en = reg_ctrl[0];

wire quad1_en;
assign quad1_en = reg_ctrl[1];

// Left Encoder
wire left_pulse;
wire left_dir;

// Right Encoder
assign quad_valid[RIGHT] = 0;


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
    .slv_reg0(reg_ctrl),
    //.slv_reg1(),
    //.slv_reg2(),
    //.slv_reg3(),

    // writeable registers
    .slv_reg1_in(reg_quad0_low_in),
    .slv_reg2_in(reg_quad0_hi_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0110),    // 0010, means reg1,reg2 is writeable.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

quadrature left_quad_inst
(
    .clk(hba_clk),
    .reset(hba_reset),

    // hba_quad input pins
    .quad_enc_a(quad_enc_a[LEFT]),
    .quad_enc_b(quad_enc_b[LEFT]),

    // outputs
    .enc_out(left_pulse),
    .enc_dir(left_dir)
);

pulse_counter left_counter_inst
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(),

    .pulse_in(left_pulse),
    .dir_in(left_dir),

    .count({reg_quad0_hi_in, reg_quad0_low_in}),   // [15:0]
    .valid(quad_valid[LEFT])
);

endmodule


