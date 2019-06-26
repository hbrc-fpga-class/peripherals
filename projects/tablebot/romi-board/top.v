/*
********************************************
* MODULE top.v
*
* This is a top level file for the hba_system module.
* It contains the board specific interfaces and
* instantiates the hba_system.
*
* Target Board: romi-board
*
* Author: Brandon Blodget
* Create Date: 06/20/2019
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
    input wire  CLK_16MHZ,

    output wire BLED,       // Tiny-BX board led

    // (SLOT 0)

    // hba_basicio pins (SLOT 1)
    input wire PIN_1,       // basicio_button[0]
    input wire PIN_2,       // basicio_button[1]
    output wire [7:0] LED,  // basicio_led

    // hba_qtr pins (SLOT 2)
    inout wire PIN_14,   // QTRR_CTRL
    inout wire PIN_15,   // QTRL_CTRL
    inout wire PIN_16,   // QTRR_OUT
    inout wire PIN_17,   // QTRL_OUT

    // hba_motor pins (SLOT 3)
    // Left motor pins
    output wire PIN_7,  // motor_pwm[0]
    output wire PIN_6,  // motor_dir[0]
    output wire PIN_5,  // motor_float_n[0]
    // Right motor pins
    output wire PIN_10,  // motor_pwm[1]
    output wire PIN_9,   // motor_dir[1]
    output wire PIN_8,   // motor_float_n[1]

    // hba_sonar pins (SLOT 4)
    output wire PIN_21,   // sonar_trig[0], L_TRIG
    input  wire PIN_20,  // sonar_echo[0], L_ECHO
    output wire PIN_19,  // sonar_trig[1], R_TRIG
    input  wire PIN_18   // sonar_echo[1], R_ECHO

);

// Parameters
parameter integer CLK_FREQUENCY = 60_000_000;
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

// hba_basicio pins
wire [7:0] basicio_led;
wire [7:0] basicio_button;

reg reset = 0;
reg [7:0] count = 0;

assign basicio_button[0] = PIN_1;
assign basicio_button[1] = PIN_2;
assign basicio_button[7:2] = 0;
assign LED = basicio_led;
assign BLED = basicio_led[0]; // copy of lsb led


// hba_sonar pins
wire [1:0] sonar_trig;
wire [1:0] sonar_echo;

assign PIN_21 = sonar_trig[0];
assign sonar_echo[0] = PIN_20;
assign PIN_19 = sonar_trig[1];
assign sonar_echo[1] = PIN_18;

// hba_qtr wires
wire [1:0] slot2_qtr_out_en;
wire [1:0] slot2_qtr_out_sig;
wire [1:0] slot2_qtr_in_sig;
wire [1:0] slot2_qtr_ctrl;
assign PIN_15 = slot2_qtr_ctrl[0];  // qtr_left
assign PIN_14 = slot2_qtr_ctrl[1];  // qtr_right

// hba_motor pins
wire [1:0] motor_pwm;
wire [1:0] motor_dir;
wire [1:0] motor_float_n;
assign PIN_7 = motor_pwm[0];
assign PIN_6 = motor_dir[0];
assign PIN_5 = motor_float_n[0];
assign PIN_10 = motor_pwm[1];
assign PIN_9 = motor_dir[1];
assign PIN_8 = motor_float_n[1];

/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 50mhz clock
pll_60mhz pll_60mhz_inst (
    .clock_in(CLK_16MHZ),
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

    // SLOT(0) : hba_master_tbc

    // SLOT(1) : hba_basicio pins
    .basicio_led(basicio_led),
    .basicio_button(basicio_button),

    // SLOT(2) : hba_qtr pins
    .qtr_out_en(slot2_qtr_out_en),
    .qtr_out_sig(slot2_qtr_out_sig),
    .qtr_in_sig(slot2_qtr_in_sig),
    .qtr_ctrl(slot2_qtr_ctrl),

    // SLOT(3) : hba_motor pins
    .motor_pwm(motor_pwm[1:0]),
    .motor_dir(motor_dir[1:0]),
    .motor_float_n(motor_float_n[1:0]),

    // SLOT(4) : hba_sonar pins
    .sonar_trig(sonar_trig),
    .sonar_echo(sonar_echo)
);

// SLOT2: QTRL_CTRL
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_qtr_port0_inst  (
    .PACKAGE_PIN(PIN_17),
    .OUTPUT_ENABLE(slot2_qtr_out_en[0]),
    .D_OUT_0(slot2_qtr_out_sig[0]),
    .D_IN_0(slot2_qtr_in_sig[0])
);

// SLOT2: QTRR_CTRL
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) slot2_qtr_port1_inst  (
    .PACKAGE_PIN(PIN_16),
    .OUTPUT_ENABLE(slot2_qtr_out_en[1]),
    .D_OUT_0(slot2_qtr_out_sig[1]),
    .D_IN_0(slot2_qtr_in_sig[1])
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

