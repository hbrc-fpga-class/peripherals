/*
*****************************
* MODULE : qtr_tb
*
* Testbench for the qtr module.
*
* Author : Brandon Bloodget
* Create Date : 06/25/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps

module qtr_tb;

// Inputs (registers)
reg clk;
reg reset;
reg en;
reg qtr_in_sig;


// Outputs (wires)
wire [7:0] value;
wire valid;
wire qtr_out_en;
wire qtr_out_sig;

// Internal
reg one_ms;

/*
*****************************
* Instantiations
*****************************
*/

qtr #
(
    .CLK_FREQUENCY(60_000_000)
) qtr_inst
(
    .clk(clk),
    .reset(reset),
    .en(en),

    .value(value),
    .valid(valid),

    .qtr_out_en(qtr_out_en),
    .qtr_out_sig(qtr_out_sig),
    .qtr_in_sig(qtr_in_sig)
);


/*
*****************************
* Main
*****************************
*/

initial begin
    $dumpfile("qtr.vcd");
    $dumpvars(0, qtr_tb);

    clk         = 0;
    reset       = 0;
    en          = 0;
    qtr_in_sig  = 0;
    one_ms      = 0;

    // Wait 100ns
    #100;
    // Add stimulus here
    @(posedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    en = 1;
    @(posedge clk);
    @(posedge clk);
    en = 0;
    qtr_in_sig = 1;
    @(posedge one_ms);
    qtr_in_sig = 0;
    @(posedge valid);
    $display("value: %d, expect close to 100 or 1.00ms",value);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $finish;
end

// Generate a 60mhz clk
always begin
    #8.33 clk = ~clk;
end

// After a 1 ms drop qtr_in_sig low.
reg [31:0] count;
always @ (posedge clk)
begin
    if (reset) begin
        count <= 0;
        one_ms <= 0;
    end else begin
        one_ms <= 0;
        count <= count + 1;
        if (count == 60_000) begin
            one_ms <= 1;
            count <= 0;
        end
    end
end

endmodule

