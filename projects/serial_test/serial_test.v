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
    output wire txd
);


/*
********************************************
* Signals
********************************************
*/

// HBA Bus
wire hba_xferack;   // Asserted when request has been completed.
wire [DBUS_WIDTH-1:0] hba_dbus;  // The read data bus.
wire [ADDR_WIDTH-1:0] hba_abus; // The input address bus.
wire hba_rnw;         // 1=Read from register. 0=Write to register.
wire hba_select;      // Transfer in progress.
wire [DBUS_WIDTH-1:0] regbank_dbus;   // The output data bus.

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
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
) serial_fpga_inst
(
    // Serial Interface
    .rxd(rxd),
    .txd(txd),
    // XXX .intr(),

    // HBA Bus Master Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_xferack(hba_xferack),  // Asserted when request has been completed.
    .hba_dbus(regbank_dbus),       // The read data bus.
    // FIXME: handling the hba mgrant in this module for now
    // XXX input wire hba_mgrant,   // Master access has be granted.
    // XXX output reg master_request,     // Requests access to the bus.
    .master_abus(hba_abus),  // The target address. Must be zero when inactive.
    .master_rnw(hba_rnw),          // 1=Read from register. 0=Write to register.
    .master_select(hba_select),       // Transfer in progress
    .master_dbus(hba_dbus)    // The write data bus.

);

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(0)
) hba_reg_bank_inst
(
    // HBA Bus Slave Interface
    .hba_clk(clk),
    .hba_reset(reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .regbank_dbus(regbank_dbus),   // The output data bus.
    .regbank_xferack(hba_xferack)     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    // XXX .regbank_interrupt()   // not used yet
);


endmodule

