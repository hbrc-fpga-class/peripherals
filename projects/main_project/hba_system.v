/*
********************************************
* MODULE hba_system.v
*
* This module implements the full peripheral suit
* for the HBRC FPGA class.  The following
* peripherals are instantiated:
*
* Eventually:
* Slot |    Peripheral
* ------------------------
*   0  |    serial_fpga
*   1  |    hba_basicio
*   2  |    hba_gpio
*   3  |    hba_quad
*   4  |    hba_pwm
*   5  |    hba_sonar
*
*
* But for now:
* Slot |    Peripheral
* ------------------------
*   0  |    serial_fpga
*   1  |    hba_basicio
*   2  |    hba_gpio
*   3  |    hba_sonar
*
*
* Author: Brandon Blodget
* Create Date: 06/15/2019
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

module hba_system # 
(
    // Parameters
    parameter integer CLK_FREQUENCY = 60_000_000,

    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    // Default ADDR_WIDTH = 12
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH
)
(
    input wire  clk,
    input wire  reset,

    // SLOT(0) : serial_fpga pins
    input wire  rxd,
    output wire txd,
    output wire intr,

    // SLOT(1) : hba_basicio pins
    output wire [7:0] basicio_led,
    input wire [7:0] basicio_button,

    // SLOT(2) : hba_gpio pins
    output wire [3:0] gpio_out_en,
    output wire [3:0] gpio_out_sig,
    input wire [3:0] gpio_in_sig,

    // SLOT(3) : hba_sonar pins
    output wire [1:0] sonar_trig,
    input wire [1:0] sonar_echo
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

// Four slave.  Set the others to 0.
wire [15:0] hba_xferack_slave;
assign hba_xferack_slave[15:4] = 0;
wire [DBUS_WIDTH-1:0] hba_dbus_slave;  // The combined slave dbus

// Slots 1,2,3 generate interrupts, zeros for others.
wire [15:0] slave_interrupt;
assign slave_interrupt[0] = 0;
assign slave_interrupt[15:4] = 0;

// Slot 0
wire [DBUS_WIDTH-1:0] hba_dbus_slave0;   // The output data bus.

// Slot 1
wire [DBUS_WIDTH-1:0] hba_dbus_slave1;   // The output data bus.

// Slot 2
wire [DBUS_WIDTH-1:0] hba_dbus_slave2;   // The output data bus.

// Slot 3
wire [DBUS_WIDTH-1:0] hba_dbus_slave3;   // The output data bus.

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

    // Interrupts from slaves
    .slave_interrupt(slave_interrupt),

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

hba_basicio #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(1)
) hba_basicio_inst
(
    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave1),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave[1]),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    .slave_interrupt(slave_interrupt[1]),    // to interrupt controller


    // hba_basicio pins
    .basicio_led(basicio_led),
    .basicio_button(basicio_button)
);

hba_gpio #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(2)
) hba_gpio_inst
(
    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave2),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave[2]),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    .slave_interrupt(slave_interrupt[2]),    // to interrupt controller

    .gpio_out_en(gpio_out_en),
    .gpio_out_sig(gpio_out_sig),
    .gpio_in_sig(gpio_in_sig)
);

hba_sonar #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(3)
) hba_sonar_inst
(
    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave3),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave[3]),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    .slave_interrupt(slave_interrupt[3]),    // to interrupt controller

    // hba_sonar pins
    .sonar_trig(sonar_trig[1:0]),
    .sonar_echo(sonar_echo[1:0])
    // XXX .sonar_sync_in(),
    // XXX .sonar_sync_out()
);

hba_or_slaves #
(
    .DBUS_WIDTH(DBUS_WIDTH)
) hba_or_slaves_inst
(
    .hba_xferack_slave(hba_xferack_slave),

    .hba_dbus_slave0(hba_dbus_slave0),
    .hba_dbus_slave1(hba_dbus_slave1),
    .hba_dbus_slave2(hba_dbus_slave2),
    .hba_dbus_slave3(hba_dbus_slave3),
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

