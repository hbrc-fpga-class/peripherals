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

// NOTE : The convention is for index 0 to be on the left side,
// and index 1 to be on the right side.  So for example
// motor_pwm[0] is for the left motor and
// motor_pwm[1] is for the right side.

module top
(
    input wire  clk_16mhz,

    output wire user_led,       // Tiny-BX board led

    // serial_fpga pins (SLOT 0)
    input wire  fpga_rxd,
    output wire fpga_txd,
    output wire hba_intr,

    // hba_basicio pins (SLOT 1)
    input wire [1:0] basicio_button,
    output wire [7:0] basicio_led,

    // hba_qtr pins (SLOT 2)
    output wire [1:0] qtr_ctrl,
    inout wire [1:0] qtr_out,

    // hba_motor pins (SLOT 3)
    output wire [1:0] motor_pwm,
    output wire [1:0] motor_dir,
    output wire [1:0] motor_float_n,

    // hba_sonar pins (SLOT 4)
    output wire [1:0] sonar_trig,
    input wire [1:0] sonar_echo,

    // hba_quad pins (SLOT 5)
    input wire [1:0] quad_enc_a,
    input wire [1:0] quad_enc_b

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

wire sys_clk;
wire locked;

reg reset = 0;
reg [7:0] count = 0;

assign user_led = basicio_led[0]; // copy of lsb led


// hba_qtr wires
wire [1:0] qtr_out_en;
wire [1:0] qtr_out_sig;
wire [1:0] qtr_in_sig;

// debug
wire [7:0] shim_basicio_led;
// XXX assign basicio_led[0] = ~fpga_rxd;
// XXX assign basicio_led[1] = ~fpga_txd;
assign basicio_led[7:0] = shim_basicio_led[7:0];

/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 50mhz clock
pll_50mhz pll_50mhz_inst (
    .clock_in(clk_16mhz),
    .clock_out(sys_clk),
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
    .clk(sys_clk),
    .reset(reset),

    // SLOT(0) : serial_fpga pins
    .rxd(fpga_rxd),
    .txd(fpga_txd),
    .intr(hba_intr),

    // SLOT(1) : hba_basicio pins
    .basicio_led(shim_basicio_led),
    .basicio_button(basicio_button),

    // SLOT(2) : hba_qtr pins
    .qtr_out_en(qtr_out_en),
    .qtr_out_sig(qtr_out_sig),
    .qtr_in_sig(qtr_in_sig),
    .qtr_ctrl(qtr_ctrl),

    // SLOT(3) : hba_motor pins
    .motor_pwm(motor_pwm[1:0]),
    .motor_dir(motor_dir[1:0]),
    .motor_float_n(motor_float_n[1:0]),

    // SLOT(4) : hba_sonar pins
    .sonar_trig(sonar_trig),
    .sonar_echo(sonar_echo),

    // SLOT(5) : hba_quad pins
    .quad_enc_a(quad_enc_a),
    .quad_enc_b(quad_enc_b)
);

// SLOT2: QTRL_OUT
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) qtr_port0_inst  (
    .PACKAGE_PIN(qtr_out[0]),
    .OUTPUT_ENABLE(qtr_out_en[0]),
    .D_OUT_0(qtr_out_sig[0]),
    .D_IN_0(qtr_in_sig[0])
);

// SLOT2: QTRR_OUT
SB_IO #(
    .PIN_TYPE(6'b 1010_01),
    .PULLUP(1'b1)
) qtr_port1_inst  (
    .PACKAGE_PIN(qtr_out[1]),
    .OUTPUT_ENABLE(qtr_out_en[1]),
    .D_OUT_0(qtr_out_sig[1]),
    .D_IN_0(qtr_in_sig[1])
);

/*
****************************
* Main
****************************
*/

// Hold reset on power up then release.
// ice40 sets all registers to zero on power up.
// Holding reset will set to default values.
always @ (posedge sys_clk)
begin
    if (count < 10) begin
        reset <= 1;
        count <= count + 1;
    end else begin
        reset <= 0;
    end
end

endmodule

