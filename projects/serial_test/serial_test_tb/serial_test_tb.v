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
parameter integer CLK_FREQUENCY     = 100_000_000;
parameter integer BAUD              = 115_200;
parameter integer NUM_OF_BYTES      = 7;  // (serial_test.dat)

// Inputs (Registers)
reg clk_100mhz;
reg reset;

reg uart0_rd;
reg uart0_wr;
reg [7:0] tx_data;


// Outputs (Wires)
wire rx_valid;
wire tx_busy;
wire [7:0] rx_data;

// Internal
integer i;

wire rxd;
wire txd;

reg finished;
reg done;

reg [7:0] echo_cmd;
reg [7:0] echo_regaddr;
reg [7:0] read_ack;

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
    // swap the txd and rxd
    .rxd(txd),
    .txd(rxd)
);

// Test uart for generating txd and rxd
buart # (
    .CLKFREQ(CLK_FREQUENCY)
) uart_inst (
    // inputs
   .clk(clk_100mhz),
   .resetq(~reset),
   .baud(BAUD),    // [31:0] max = 32'd921600
   .rx(rxd),            // recv wire
   .rd(uart0_rd),    // read strobe
   .wr(uart0_wr),   // write strobe
   .tx_data(tx_data),   // [7:0]

   // outputs
   .tx(txd),           // xmit wire
   .valid(rx_valid),   // has recv data 
   .busy(tx_busy),     // is transmitting
   .rx_data(rx_data)   // [7:0]
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

    uart0_rd = 0;
    uart0_wr = 0;
    tx_data = 0;

    echo_cmd = 0;
    echo_regaddr = 0;
    read_ack = 0;

    // 5 clock signals
    @(posedge clk_100mhz);
    reset = 1;
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    reset = 0;
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);
    @(posedge clk_100mhz);

    write_test;

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
/*
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
        end else if (count >= 0 && count < NUM_OF_BYTES) begin
            $display("%d %x",count, tv_mem[count]);
        end
    end
end
*/

// Wait for transmitter to not be busy
task wait_for_transmit_ready;
begin
    @ (posedge clk_100mhz);
    done = 0;
    while(!done)
    begin
        @ (posedge clk_100mhz);
        if (tx_busy == 0)
        begin
            done = 1;
        end
    end
end
endtask

// Task to send a character
task send_char;
    input [7:0] char;
begin
    wait_for_transmit_ready;
    @ (posedge clk_100mhz);
    tx_data = char;
    uart0_wr = 1;
    @ (posedge clk_100mhz);
    uart0_wr = 0;
end
endtask

// Read a char
task read_char;
    output [7:0] char;
begin
    i = 0;
    done = 0;
    char = 255;
    while(!done)
    begin
        if (rx_valid==1)
        begin
            char = rx_data;
            done = 1;
        end
        @ (posedge clk_100mhz);
        i = i + 1;
        if (i == 100000)
        begin
            $display("%t: ERROR read_char",$time);
            done = 1;
        end
    end
end
endtask

// Write test
task write_test;
begin
    $display("\n%t: BEGIN write_test",$time);
    // Send the command
    $display("%t: send cmd=%d",$time,tv_mem[0]);
    send_char(tv_mem[0]);

    // Send the reg_Addr
    $display("%t: send regaddr=%d",$time,tv_mem[1]);
    send_char(tv_mem[1]);

    // send data
    $display("%t: send data0=%d",$time,tv_mem[2]);
    send_char(tv_mem[2]);
    $display("%t: send data1=%d",$time,tv_mem[3]);
    send_char(tv_mem[3]);
    $display("%t: send data2=%d",$time,tv_mem[4]);
    send_char(tv_mem[4]);
    $display("%t: send data3=%d",$time,tv_mem[5]);
    send_char(tv_mem[5]);

    // Read ACK
    send_char(tv_mem[6]);
    read_char(read_ack);
    $display("%t:   recv read_ack=%x",$time,read_ack);

    $display("\n%t: END write_test",$time);
end
endtask


endmodule
