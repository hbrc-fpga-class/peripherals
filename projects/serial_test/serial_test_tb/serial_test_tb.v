/*
********************************************
* MODULE serial_test_tb.v
*
* This is testbench for the serial_test
*
* Author: Brandon Blodget
* Create Date: 05/12/2019
*
********************************************
*/

`timescale 1 ns / 1 ns

// Force error when implicit net has no type.
`default_nettype none

module serial_test_tb;

// Inputs (Registers)
reg clk_100mhz;
reg reset;
reg rxd;


// Outputs (Wires)
wire txd;

/*
********************************************
* Instantiate DUT
********************************************
*/

serial_test dut
(
    .clk_100mhz(clk_100mhz),
    .reset(reset),
    .rxd(rxd),
    .txd(txd)
);

/*
********************************************
* Main
********************************************
*/

initial
begin
    $dumpfile("serial_test.vcd");
    $dumpvars;
    clk_100mhz = 0;
    reset = 0;
    rxd = 0;

    // 5 clock signals
    @(posedge clk_100mhz);
    reset = 1;
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    reset = 0;
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    $finish;

end

// Generate 100Mhz clock
always
begin
    #5 clk_100mhz <= ~clk_100mhz;
end


endmodule
