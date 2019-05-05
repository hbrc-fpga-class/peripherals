/*
*****************************
* MODULE : hba_reg_bank_tb
*
* Testbench for the hba_reg_bank module.
*
* Author : Brandon Bloodget
* Create Date : 05/04/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps

module hba_reg_bank_tb;

// Parameters
parameter integer DBUS_WIDTH = 8;
parameter integer PERIPH_ADDR_WIDTH = 4;
parameter integer REG_ADDR_WIDTH = 8;
parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH;
parameter integer PERIPH_ADDR = 5;

// Inputs (registers)
reg hba_clk;
reg hba_reset;
reg hba_rnw;
reg hba_select;
reg [ADDR_WIDTH-1:0] hba_abus;
reg [DBUS_WIDTH-1:0] hba_dbus;

// Outputs (wires)
wire [DBUS_WIDTH-1:0] regbank_dbus;
wire regbank_xferack;
wire regbank_interrupt;

// Internal wires

/*
*****************************
* Instantiations
*****************************
*/

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(PERIPH_ADDR)
) dut
(
    // HBA Bus Slave Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),   // Indicates transfer in progress
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .regbank_dbus(regbank_dbus),   // The output data bus.
    .regbank_xferack(regbank_xferack),   // The output data bus.
    .regbank_interrupt(regbank_interrupt)     // Send interrupt back
);

/*
*****************************
* Main
*****************************
*/
initial begin
    $dumpfile("hba_reg_bank.vcd");
    $dumpvars(0, hba_reg_bank_tb);
    hba_clk = 0;
    hba_reset = 0;
    hba_rnw = 0;
    hba_select = 0;
    hba_abus = 0;
    hba_dbus = 0;

    // Wait 100ns
    #100;
    // Add stimulus here
    @(posedge hba_clk);
    hba_reset = 1;
    @(posedge hba_clk);
    @(posedge hba_clk);
    hba_reset = 0;
    @(posedge hba_clk);
    // Setup a write to reg1=0x12
    hba_abus = 12'h501;
    hba_dbus = 8'h12;
    hba_rnw = 0;
    hba_select = 1;
    @(posedge regbank_xferack);
    hba_select = 0;
    $display("");
    $display("***WRITE to reg1=0x12");
    $display("hba_abus: %x",hba_abus);
    $display("hba_dbus: %x",hba_dbus);
    $display("periph_addr: %x",dut.periph_addr);
    $display("PERIPH_ADDR: %x",PERIPH_ADDR);
    $display("addr_decode_hit: %x",dut.addr_decode_hit);
    $display("reg1: %x",dut.reg1);
    @(negedge regbank_xferack);
    @(posedge hba_clk);
    @(posedge hba_clk);
    $display("");
    $display("addr_hit: %x, Done so should be 0.",dut.addr_hit);
    @(posedge hba_clk);
    // Setup a read from reg1
    hba_abus = 12'h501;
    hba_dbus = 8'h00;
    hba_rnw = 1;
    hba_select = 1;
    @(posedge regbank_xferack);
    hba_select = 0;
    // Check value on the regbank_dbus
    $display("");
    $display("***READ reg1 from regbank_dbus");
    $display("regbank_dbus: %x",regbank_dbus);
    @(negedge regbank_xferack);
    @(posedge hba_clk);
    @(posedge hba_clk);
    @(posedge hba_clk);
    $finish;
end


// Generate a 100mhz clk
always begin
    #5 hba_clk <= ~hba_clk;
end

endmodule

