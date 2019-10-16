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
    parameter integer CLK_FREQUENCY = 50_000_000,
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
    input wire [1:0] quad_enc_b,
    output wire [7:0] quad_speed_left,
    output wire [7:0] quad_speed_right,
    output wire quad_speed_pulse
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

wire [DBUS_WIDTH-1:0] reg_quad0_low_in; // reg1: Lower 8-bits of quad0
wire [DBUS_WIDTH-1:0] reg_quad0_hi_in;  // reg2: Upper 8-bit of quad0

wire [DBUS_WIDTH-1:0] reg_quad1_low_in; // reg3: Lower 8-bits of quad1
wire [DBUS_WIDTH-1:0] reg_quad1_hi_in;  // reg4: Upper 8-bit of quad1


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

wire reg_reset;  // reg0[3]: Used to reset encoders.
assign reg_reset = reg_ctrl[3];
reg reg_reset2;
reg reg_reset_pos_edge;


// Left Encoder
wire left_pulse;
wire left_dir;
wire [DBUS_WIDTH-1:0] hba_dbus_slave0;
wire hba_xferack_slave0;

// Right Encoder
wire right_pulse;
wire right_dir;
wire [DBUS_WIDTH-1:0] hba_dbus_slave1;
wire hba_xferack_slave1;

// Combine the two address banks.
assign hba_dbus_slave = hba_dbus_slave0 | hba_dbus_slave1;
assign hba_xferack_slave = hba_xferack_slave0 | hba_xferack_slave1;

wire enc_reset = hba_reset | reg_reset_pos_edge;

// Timer pulse
wire [7:0] reg_rate_ms;

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
) hba_reg_bank_inst0
(
    // HBA Bus Slave Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave0),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave0),     // Acknowledge transfer requested. 
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
    .slv_reg3_in(reg_quad1_low_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b1110),    // reg 1,2,3 writable by this module
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(PERIPH_ADDR),
    .REG_OFFSET(4)
) hba_reg_bank_inst1
(
    // HBA Bus Slave Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave1),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave1),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.

    // Access to registgers
    //.slv_reg0(),
    //.slv_reg1(reg_rate_ms),
    //.slv_reg2(),
    .slv_reg3(reg_rate_ms), // reg7

    // writeable registers
    .slv_reg0_in(reg_quad1_hi_in), // reg4
    .slv_reg1_in(quad_speed_left),  // reg5
    .slv_reg2_in(quad_speed_right), // reg6
    //.slv_reg3_in(),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0111),    // reg0,1,2 writable by this module
    .slv_autoclr_mask(4'b0000)    // no autoclear
);

quadrature left_quad_inst
(
    .clk(hba_clk),
    .reset(enc_reset),

    // hba_quad input pins
    .quad_enc_a(quad_enc_a[LEFT]),
    .quad_enc_b(quad_enc_b[LEFT]),

    // outputs
    .enc_out(left_pulse),
    .enc_dir(left_dir)
);

pulse_counter #
(
    .FWD(1)
) left_counter_inst
(
    .clk(hba_clk),
    .reset(enc_reset),
    .en(quad0_en),

    .pulse_in(left_pulse),
    .dir_in(left_dir),

    .speed_interval_pulse(quad_speed_pulse),
    .speed_count(quad_speed_left),

    .count({reg_quad0_hi_in[7:0], reg_quad0_low_in[7:0]}),   // [15:0]
    .valid(quad_valid[LEFT])
);

quadrature right_quad_inst
(
    .clk(hba_clk),
    .reset(enc_reset),

    // hba_quad input pins
    .quad_enc_a(quad_enc_a[RIGHT]),
    .quad_enc_b(quad_enc_b[RIGHT]),

    // outputs
    .enc_out(right_pulse),
    .enc_dir(right_dir)
);

pulse_counter #
(
    .FWD(1)
) right_counter_inst
(
    .clk(hba_clk),
    .reset(enc_reset),
    .en(quad1_en),

    .pulse_in(right_pulse),
    .dir_in(right_dir),

    .speed_interval_pulse(quad_speed_pulse),
    .speed_count(quad_speed_right),

    .count({reg_quad1_hi_in[7:0], reg_quad1_low_in[7:0]}),   // [15:0]
    .valid(quad_valid[RIGHT])
);

timer_pulse #
(
    .CLK_FREQUENCY(CLK_FREQUENCY)
) timer_pulse_inst
(
    .clk(hba_clk),
    .reset(hba_reset),
    .rate_ms(reg_rate_ms),    // [7:0]

    .pulse(quad_speed_pulse)
);

/*
*****************************
* Main
*****************************
*/


// Capture edges on reg_reset for enc_reset
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        reg_reset2 <= 0;
        reg_reset_pos_edge <= 0;
    end else begin
        reg_reset2 <= reg_reset;
        reg_reset_pos_edge <= reg_reset & ~reg_reset2;
    end
end

endmodule


