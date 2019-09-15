/*
*****************************
* MODULE : hba_motor.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It provides an interface to control two motor driver circuits.
* For each motor there is a pwm and a direction signal.
* The pwm frequency defaults to 100khz.  The width of the pwm
* signal controls the power of the motor.
*
* See the README.md in this directory for more information.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/21/2019
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

module hba_motor #
(
    // Defaults
    // DBUS_WIDTH = 8
    // ADDR_WIDTH = 12
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH,
    parameter integer PERIPH_ADDR = 0,
    parameter integer CLK_FREQUENCY = 60_000_000,
    parameter integer PWM_FREQUENCY = 100_000
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

    // hba_motor pins
    input wire [15:0] slave_estop,
    output wire [1:0] motor_pwm,
    output wire [1:0] motor_dir,
    output wire [1:0] motor_float_n
);

/*
*****************************
* local params
*****************************
*/

localparam LEFT         = 0;
localparam RIGHT        = 1;

localparam EN_LEFT      = 0;
localparam EN_RIGHT     = 1;
localparam DIR_LEFT     = 2;
localparam DIR_RIGHT    = 3;
localparam COAST_LEFT   = 4;
localparam COAST_RIGHT  = 5;

/*
*****************************
* Signals and Assignments
*****************************
*/

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_mode;         // reg0: Control register
wire [DBUS_WIDTH-1:0] reg_power_left;   // reg1: Left Power register
wire [DBUS_WIDTH-1:0] reg_power_right;  // reg2: Right Power register

// No interrupts
assign slave_interrupt = 0;

// Any of peripherals generating an estop?
wire estop = (|slave_estop[15:0]);
reg estop_posedge;

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
    .slv_reg0(reg_mode),
    .slv_reg1(reg_power_left),
    .slv_reg2(reg_power_right),

    // writeable registers (none)
    // XXX .slv_reg1_in(),
    // XXX .slv_reg2_in(),

    .slv_wr_en(1'b0),   // Assert to set slv_reg? <= slv_reg?_in (nope)
    .slv_wr_mask(4'b0000),    // 0000, means no writeable registers.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

pmw_dir #
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .PWM_FREQUENCY(PWM_FREQUENCY)
) pwm_dir_left_inst
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(reg_mode[EN_LEFT]),
    .float(reg_mode[COAST_LEFT]),
    .duty_cycle(reg_power_left[6:0]),   // [6:0]
    .dir_in(reg_mode[DIR_LEFT]),
    .estop(estop_posedge),

    .pwm(motor_pwm[LEFT]),
    .dir_out(motor_dir[LEFT]),
    .float_n(motor_float_n[LEFT])
);

pmw_dir #
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .PWM_FREQUENCY(PWM_FREQUENCY)
) pwm_dir_right_inst
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(reg_mode[EN_RIGHT]),
    .float(reg_mode[COAST_RIGHT]),
    .duty_cycle(reg_power_right[6:0]),   // [6:0]
    .dir_in(reg_mode[DIR_RIGHT]),
    .estop(estop_posedge),

    .pwm(motor_pwm[RIGHT]),
    .dir_out(motor_dir[RIGHT]),
    .float_n(motor_float_n[RIGHT])
);

// Generate the estop pulses
reg estop_reg;
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        estop_reg <= 0;
        estop_posedge <= 0;
    end else begin
        estop_reg <= estop;
        estop_posedge <= estop & ~estop_reg;
    end
end


endmodule

