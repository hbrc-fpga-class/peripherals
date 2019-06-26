/*
*****************************
* MODULE : sr04_tb
*
* Testbench for the sr04 module.
*
* Author : Brandon Bloodget
* Create Date : 06/14/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps


module sr04_tb;

// Inputs (registers)
reg clk;
reg reset;
reg en;
reg sync;
reg echo;

// Output (wires)
wire trig;
wire [7:0] dist;
wire valid;

/*
*****************************
* Instantiations
*****************************
*/

sr04 sr04_inst
(
    .clk(clk),     // assume 50mhz
    .reset(reset),
    .en(en),
    .sync(sync),

    .trig(trig),
    .echo(echo),

    .dist(dist),    // [7:0] actually time which is proportional to dist
    .valid(valid)   // new dist value
);

/*
*****************************
* Main
*****************************
*/

initial begin
    $dumpfile("sr04.vcd");
    $dumpvars(0, sr04_tb);

    clk     = 0;
    reset   = 0;
    en      = 0;
    sync    = 0;
    echo    = 0;

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
    sync = 1;
    @(posedge clk);
    sync = 0;
    @(posedge clk);
    @(posedge echo);
    @(posedge clk);
    @(posedge clk);
    $display("dist: %d",dist);
    $display("dist(in): %d",(dist*0.55));
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

// Generate a 50mhz clk
always begin
    #10 clk = ~clk;
end

// Find falling edge of trigger.
reg trig_reg;
wire trig_negedge;
assign trig_negedge = (trig==0) && (trig_reg==1);
always @ (posedge clk)
begin
    if (reset) begin
        trig_reg <= 0;
    end else begin
        trig_reg <= trig;
    end
end

// Generate an echo after 1.5ms.
// Which should be approx 10 inches.
// 1.5ms/20ns = 75,000
reg [16:0] ecount;
reg start_ecount;
always @ (posedge clk)
begin
    if (reset) begin
        ecount <= 0;
        start_ecount <= 0;
        echo <= 0;
    end else begin
        echo <= 0;
        if (trig_negedge) begin
            start_ecount <= 1;
        end
        if (start_ecount) begin
            ecount <= ecount + 1;
            if (ecount == 75_000) begin
                echo <= 1;
            end
        end
    end
end

endmodule

