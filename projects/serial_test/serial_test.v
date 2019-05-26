/*
********************************************
* MODULE serial_test.v
*
* This module implements the serial_fpga master connected
* to one hba_reg_bank slave.  It is used to test
* that we can read and write to the hba_reg_bank slave
* registers from the serial port.
*
* Target Board: TinyFPGA BX
*
* Author: Brandon Blodget
* Create Date: 05/12/2019
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

module serial_test # 
(
    // Parameters
    parameter integer CLK_FREQUENCY = 50_000_000,
    parameter integer BAUD = 32'd115_200,

    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    // Default ADDR_WIDTH = 12
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH
)
(
    input wire  clk,
    input wire  reset,
    input wire  rxd,
    output wire txd,
    output wire intr
);


/*
********************************************
* Signals
********************************************
*/

// HBA Bus
wire [DBUS_WIDTH-1:0] hba_dbus;  // The read data bus.
wire [ADDR_WIDTH-1:0] hba_abus; // The input address bus.
wire hba_rnw;         // 1=Read from register. 0=Write to register.
wire hba_select;      // Transfer in progress.
wire hba_xferack;       // Slave ACK transfer complete.

// Only two slave.  Set the others to 0.
wire [15:0] hba_xferack_slave;
assign hba_xferack_slave[15:2] = 0;
wire [DBUS_WIDTH-1:0] hba_dbus_slave;  // The combined slave dbus

// Slot 0
wire hba_xferack_slave0;   // Asserted when request has been completed.
wire [DBUS_WIDTH-1:0] hba_dbus_slave0;   // The output data bus.

// Slot 1
wire hba_xferack_slave1;   // Asserted when request has been completed.
wire [DBUS_WIDTH-1:0] hba_dbus_slave1;   // The output data bus.

// Master 0 (only 1)
wire [3:0] hba_rnw_master;
wire [3:0] hba_select_master;
assign hba_rnw_master[3:1] = 0;
assign hba_select_master[3:1] = 0;

wire [DBUS_WIDTH-1:0] hba_dbus_master0;
wire [ADDR_WIDTH-1:0] hba_abus_master0;

wire [3:0] hba_mrequest;
wire [3:0] hba_mgrant;
assign hba_mrequest[3:1] = 0;

/*
****************************
* Instantiations
****************************
*/

serial_fpga #
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .BAUD(BAUD),

    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(0)
) serial_fpga_inst
(
    // Serial Interface
    .io_rxd(rxd),
    .io_txd(txd),
    .io_intr(intr),

    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave0),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave[0]),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.

    // HBA Bus Master Interface
    .hba_xferack(hba_xferack),  // Asserted when request has been completed.
    .hba_mgrant(hba_mgrant[0]),   // Master access has be granted.
    .hba_mrequest(hba_mrequest[0]),     // Requests access to the bus.
    .hba_abus_master(hba_abus_master0),  // The target address. Must be zero when inactive.
    .hba_rnw_master(hba_rnw_master[0]),          // 1=Read from register. 0=Write to register.
    .hba_select_master(hba_select_master[0]),       // Transfer in progress
    .hba_dbus_master(hba_dbus_master0)    // The write data bus.

);

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(1)
) hba_reg_bank_inst
(
    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave1),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave[1])     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    // XXX .regbank_interrupt()   // not used yet
);

hba_or_slaves #
(
    .DBUS_WIDTH(DBUS_WIDTH)
) hba_or_slaves_inst
(
    .hba_xferack_slave(hba_xferack_slave),

    .hba_dbus_slave0(hba_dbus_slave0),
    .hba_dbus_slave1(hba_dbus_slave1),
    .hba_dbus_slave2(0),
    .hba_dbus_slave3(0),
    .hba_dbus_slave4(0),
    .hba_dbus_slave5(0),
    .hba_dbus_slave6(0),
    .hba_dbus_slave7(0),

    .hba_dbus_slave8(0),
    .hba_dbus_slave9(0),
    .hba_dbus_slave10(0),
    .hba_dbus_slave11(0),
    .hba_dbus_slave12(0),
    .hba_dbus_slave13(0),
    .hba_dbus_slave14(0),
    .hba_dbus_slave15(0),

    .hba_xferack(hba_xferack),
    .hba_dbus_slave(hba_dbus_slave)
);

hba_or_masters #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) hba_or_masters_inst
(
    .hba_rnw_master(hba_rnw_master),
    .hba_select_master(hba_select_master),

    // Need to OR the slave dbus with the masters
    .hba_dbus_slave(hba_dbus_slave),
    .hba_dbus_master0(hba_dbus_master0),
    .hba_dbus_master1(0),
    .hba_dbus_master2(0),
    .hba_dbus_master3(0),

    .hba_abus_master0(hba_abus_master0),
    .hba_abus_master1(0),
    .hba_abus_master2(0),
    .hba_abus_master3(0),

    .hba_rnw(hba_rnw),
    .hba_select(hba_select),
    .hba_dbus(hba_dbus),
    .hba_abus(hba_abus)
);

hba_arbiter hba_arbiter_inst
(
    .hba_clk(clk),
    .hba_reset(reset),

    .hba_select(hba_select),      // indicates active master
    .hba_mrequest(hba_mrequest),
    .hba_mgrant(hba_mgrant)
);

endmodule

