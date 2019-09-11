/*
*****************************
* MODULE : hba_qtr.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* This module provides an interface to two
* QTR reflectance sensors from Pololu.
* Each sensor returns an 8-bit value which represents
* The time it took for the QTR output pin to go
* low after being charged.  The higher the reflectance
* the shorter the time for the pin to go low.  The resolution
* of the 8-bit value is in 10us.  So max value of
* 255 gives a time of 2.55ms.
*
* See the README.md for information about the register interface.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/26/2019
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

module hba_qtr #
(
    // Defaults
    // DBUS_WIDTH = 8
    // ADDR_WIDTH = 12
    parameter integer CLK_FREQUENCY = 60_000_000,
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
    output wire slave_estop,       // Estop to hba_motor.  Pulse stops.

    // hba_qtr pins
    output wire [1:0]  qtr_out_en,
    output wire [1:0] qtr_out_sig,
    input wire [1:0] qtr_in_sig,
    output wire [1:0] qtr_ctrl
);

/*
*****************************
* Signals and Assignments
*****************************
*/

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_ctrl;  // reg0: Control register

wire [DBUS_WIDTH-1:0] reg_qtr0_in;  // reg1: qtr0 value
wire [DBUS_WIDTH-1:0] reg_qtr1_in;  // reg2: qtr1 value

wire [DBUS_WIDTH-1:0] reg_period;  // reg3: Trigger period

// Enables writing to slave registers.
wire slv_wr_en;

// Indicates new sonar data
wire [1:0] qtr_valid;

// The trigger sync signal
reg qtr_sync;

// Enable interrupt bit
wire intr_en = reg_ctrl[2];

assign slave_interrupt = (|qtr_valid) & intr_en;
assign slv_wr_en = |qtr_valid;

wire qtr0_en;
assign qtr0_en = reg_ctrl[0] & qtr_sync;

wire qtr1_en;
assign qtr1_en = reg_ctrl[1] & qtr_sync;

// Interrupt type, Period=0, Threshold=1
localparam INTR_TYPE_PERIOD = 0;
localparam INTR_TYPE_THRESH = 1;
wire intr_type = reg_ctrl[3];

// Emergency Stop enable
wire estop_en = reg_ctrl[4];

// Combine the two address banks.
wire [DBUS_WIDTH-1:0] hba_dbus_slave0;
wire [DBUS_WIDTH-1:0] hba_dbus_slave1;
wire hba_xferack_slave0;
wire hba_xferack_slave1;

assign hba_dbus_slave = hba_dbus_slave0 | hba_dbus_slave1;
assign hba_xferack_slave = hba_xferack_slave0 | hba_xferack_slave1;

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
    .slv_reg3(reg_period),

    // writeable registers
    .slv_reg1_in(reg_qtr0_in),
    .slv_reg2_in(reg_qtr1_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0110),    // 0010, means reg1,reg2 is writeable.
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
    .slv_reg0(reg_ctrl),
    //.slv_reg1(),
    //.slv_reg2(),
    .slv_reg3(reg_period),

    // writeable registers
    .slv_reg1_in(reg_qtr0_in),
    .slv_reg2_in(reg_qtr1_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0110),    // 0010, means reg1,reg2 is writeable.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

// Left QTR
qtr #
(
    .CLK_FREQUENCY(CLK_FREQUENCY)
) qtr_inst0
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(qtr0_en),

    .value(reg_qtr0_in),    // [7:0]
    .valid(qtr_valid[0]),

    // hba_qtr pins
    .qtr_out_en(qtr_out_en[0]),
    .qtr_out_sig(qtr_out_sig[0]),
    .qtr_in_sig(qtr_in_sig[0]),
    .qtr_ctrl(qtr_ctrl[0])

);

// Right QTR
qtr #
(
    .CLK_FREQUENCY(CLK_FREQUENCY)
) qtr_inst1
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(qtr1_en),

    .value(reg_qtr1_in),    // [7:0]
    .valid(qtr_valid[1]),

    // hba_qtr pins
    .qtr_out_en(qtr_out_en[1]),
    .qtr_out_sig(qtr_out_sig[1]),
    .qtr_in_sig(qtr_in_sig[1]),
    .qtr_ctrl(qtr_ctrl[1])

);


/*
*****************************
* Main
*****************************
*/

// Generate the qtr_sync signal
reg [22:0] count_50ms;
reg [7:0] count_period;
localparam FIFTY_MS_COUNT = ( CLK_FREQUENCY / 20 );
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        qtr_sync <= 0;
        count_50ms <= 0;
        count_period <= 0;
    end else begin
        qtr_sync <= 0;
        count_50ms <= count_50ms + 1;
        if (count_50ms == (FIFTY_MS_COUNT-1)) begin
            count_50ms <= 0;
            count_period <= count_period + 1;
            if (count_period == reg_period) begin
                count_period <= 0;
                qtr_sync <= 1;
            end
        end
    end
end


endmodule

