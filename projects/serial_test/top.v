/*
********************************************
* MODULE top.v
*
* This project implements the serial_fpga master connected
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

module top
(
    input wire  CLK_16MHZ,

    input wire  PIN_1,  // rxd
    output wire PIN_2,  // txd


    output wire LED     // pll locked
);

// Parameters
parameter integer CLK_FREQUENCY = 100_000_000;
parameter integer BAUD = 32'd115_200;

parameter integer DBUS_WIDTH = 8;
parameter integer PERIPH_ADDR_WIDTH = 4;
parameter integer REG_ADDR_WIDTH = 8;

/*
********************************************
* Signals
********************************************
*/

wire clk_100mhz;
wire locked;
wire rxd;
wire txd;

reg reset = 0;
reg [7:0] count = 0;

assign PIN_1 = rxd;
assign PIN_2 = txd;
assign LED = locked;


/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 100mhz clock
pll_100mhz pll_100mhz_inst (
    .clock_in(CLK_16MHZ),
    .clock_out(clk_100mhz),
    .locked(locked)
);

serial_test serial_test_inst
(
    .clk_100mhz(clk_100mhz),
    .reset(reset),
    .rxd(rxd),
    .txd(txd)
);

/*
****************************
* Main
****************************
*/

// Hold reset on power up then release.
// ice40 sets all registers to zero on power up.
// Holding reset will set to default values.
always @ (posedge clk_100mhz)
begin
    if (count < 10) begin
        reset <= 1;
        count <= count + 1;
    end else begin
        reset <= 0;
    end
end

endmodule

