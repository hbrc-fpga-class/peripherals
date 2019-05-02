/*
*****************************
* MODULE : serial_fpga
*
* This module implements a bridge between
* a RS232 serial interface and the
* HomeBrew Automation Bus (HBA).  It allows an
* external processor like a Raspberry Pi
* control the FPGA peripherals on the HBA Bus.
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

module serial_fpga #
(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer BAUD = 32'd115_200
)
(
    input wire hba_clk,
    input wire hba_reset,

    // Serial Interface
    input wire rxd,
    input wire rts,
    output wire txd,
    output wire cts,
    output wire intr,

    // HBA Bus Master Interface
    input hba_mgrant,   // Master access has be granted.
    input hba_xferack,  // Asserted when request has been completed.
    input [7:0] hba_dbus,       // The read data bus.
    output masterx_request,     // Requests access to the bus.
    output [11:0] master_abus,  // The target address. Must be zero when inactive.
    output master_rnw,          // 1=Read from register. 0=Write to register.
    output [7:0] master_dbus    // The write data bus.

);

/*
****************************
* Signals
****************************
*/

reg read_strobe;
reg write_strobe;
reg [7:0] tx_data;

wire rx_valid;
wire tx_busy;
wire [7:0] rx_data;

reg [31:0] uart_baud = BAUD; // max = 32'd921600;

/*
****************************
* Instantiations
****************************
*/

buart # (
    .CLKFREQ(CLK_FREQUENCY)
) uart_inst (
    // inputs
   .clk(hba_clk),
   .resetq(~hba_reset),
   .baud(uart_baud),    // [31:0]
   .rx(rxd),            // recv wire
   .rd(read_strobe),    // read strobe
   .wr(write_strobe),   // write strobe
   .tx_data(tx_data),   // [7:0]

   // outputs
   .tx(txd),           // xmit wire
   .valid(rx_valid),   // has recv data 
   .busy(tx_busy),     // is transmitting
   .rx_data(rx_data)   // [7:0]
);


endmodule

