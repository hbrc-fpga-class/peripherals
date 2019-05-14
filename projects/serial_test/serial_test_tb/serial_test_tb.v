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

// Parameters
parameter integer NUM_OF_BYTES = 6;  // (serial_test.dat)

// Inputs (Registers)
reg clk_100mhz;
reg reset;
reg rxd;


// Outputs (Wires)
wire txd;

// Internal
reg finished;

// TestBench memory
reg [7:0] tv_mem [0:NUM_OF_BYTES-1];

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
    $readmemh("serial_test.dat", tv_mem);
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
    @(posedge finished);
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

// Test reading from tv_mem
reg [15:0] count;
always @ (posedge clk_100mhz)
begin
    if (reset) begin
        count <= 0;
        finished <= 0;
    end else begin
        count <= count + 1;
        if (count == NUM_OF_BYTES) begin
            finished <= 1;
        end else begin 
            if (count >= 0 && count < NUM_OF_BYTES) begin
                $display("%d %x",count, tv_mem[count]);
            end
        end
    end
end

endmodule
