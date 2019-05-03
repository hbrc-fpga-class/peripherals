/*
*****************************
* MODULE : hba_reg_bank
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It creates a few registers that can be accessed over the bus.
*
* It is used for the development of the basic 
* HBA infrastructure.
*
* It can also be used as a template for developing
* new HBA peripherals.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/02/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

module hba_reg_bank #
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
    input wire hba_rwn,         // 1=Read from register. 0=Write to register.
    input wire [ADDR_WIDTH-1:0] hba_abus, // The input address bus.
    input wire [DBUS_WIDTH-1:0] hba_dbus,  // The input data bus.

    output wire [DBUS_WIDTH-1:0] slave_dbus,   // The output data bus.
    output wire slave_interrupt     // Send interrupt back
);

/*
*****************************
* Signals
*****************************
*/


/*
*****************************
* Assignments
*****************************
*/

assign slave_interrupt = 0;     // No interrupts

// logic to decode addresses
assign addr_decode_hit = (hba_abus


endmodule
