/*
*****************************
* MODULE : hba_sonar.v
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It provides an interface to control two SR04 sonars.
* It also has a trigger sync input, and registers for
* specifying offsets from the trigger sync.  This way
* if there are multiple sonar peripherals the triggers can
* be staggered so they don't all fire at the same time and
* cause a large current draw.
*
* Register Interface
*
* __reg0__ : Control register. Enables sonars and interrupts.
*    reg0[0] : Enable sonar 0.
*    reg0[1] : Enable sonar 1.
*    reg0[2] : Slave sync.  If 1 use the sonar_sync_in for trigger.
*Default(0) generate internal sync pulse.
*    reg0[3] : Enable sonar interrupt. Triggered once per cycle.
*    reg0[7:4] : Unused
* __reg1__ : Time slice for sonar 0 trigger after sync. Granularity 1ms.
* __reg2__ : Time slice for sonar 1 trigger after sync. Granularity 1ms.
* __reg3__ : Trigger period.  Granularity 50ms. Default 100ms.
*
* See the README.md in this directory for more information.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/08/2019
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

module hba_sonar #
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

    // hba_sonar pins
    output wire [1:0] sonar_trig,
    input wire [1:0] sonar_echo,
    input wire sonar_sync_in,
    output wire sonar_sync_out
);

/*
*****************************
* Signals and Assignments
*****************************
*/

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_ctrl;  // reg0: Control register

wire [DBUS_WIDTH-1:0] reg_sonar0_in;  // reg1: Sonar0 value
wire [DBUS_WIDTH-1:0] reg_sonar1_in;  // reg2: Sonar1 value

wire [DBUS_WIDTH-1:0] reg_delay0;  // reg3: Sonar0 trigger delay
wire [DBUS_WIDTH-1:0] reg_delay1;  // reg4: Sonar1 trigger delay
wire [DBUS_WIDTH-1:0] reg_period;  // reg5: Trigger period

// Enables writing to slave registers.
wire slv_wr_en;

// Indicates new sonar data
wire [1:0] sonar_valid;

// The trigger sync signal
reg sonar_sync;

assign slave_interrupt = sonar_valid;
assign slv_wr_en = sonar_valid;

// TODO : Fix when add 2nd sonar.
assign sonar_trig[1] = 0;

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
    
    // TODO : Add these later
    // XXX .slv_reg3(reg_delay0),
    // XXX .slv_reg4(reg_delay1),
    // XXX .slv_reg5(reg_period),

    // writeable registers
    .slv_reg1_in(reg_sonar0_in),
    // XXX .slv_reg2_in(reg_sonar1_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0010),    // 0010, means reg1 is writeable.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

sr04 sr04_inst0
(
    .clk(hba_clk),     // assume 50mhz
    .reset(hba_reset),
    .sync(sonar_sync),

    .trig(sonar_trig[0]),
    .echo(sonar_echo[0]),

    .dist(reg_sonar0_in),  // actually time which is proportional to dist
    .valid(sonar_valid[0])  // new dist value
);

// TODO : Add 2nd sonar.

/*
*****************************
* Main
*****************************
*/

// Generate the sonar_sync signal
// 100ms period = 5_000_000 clocks @ 50mhz
reg [22:0] sync_count;
localparam SYNC_COUNT_MAX = 5_000_000;
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        sonar_sync <= 0;
        sync_count <= 0;
    end else begin
        sonar_sync <= 0;
        sync_count <= sync_count + 1;
        if (sync_count == (SYNC_COUNT_MAX-1)) begin
            sync_count <= 0;
            sonar_sync <= 1;
        end
    end
end


endmodule

