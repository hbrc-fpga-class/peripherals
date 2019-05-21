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
parameter integer CLK_FREQUENCY     = 50_000_000;
parameter integer BAUD              = 115_200;
parameter integer NUM_OF_BYTES      = 15;  // (serial_test.dat)

// Inputs (Registers)
reg clk;
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
reg [7:0] read_data;

// TestBench memory
reg [7:0] tv_mem [0:NUM_OF_BYTES-1];

/*
********************************************
* Instantiate DUT
********************************************
*/

serial_test #
(
    .CLK_FREQUENCY(CLK_FREQUENCY),
    .BAUD(BAUD)
) dut (
    .clk(clk),
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
   .clk(clk),
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
    clk = 0;
    reset = 0;

    uart0_rd = 0;
    uart0_wr = 0;
    tx_data = 0;

    echo_cmd = 0;
    echo_regaddr = 0;
    read_ack = 0;
    read_data = 0;

    // 5 clock signals
    @(posedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);

    write_test;
    read_test;

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);

    $finish;

end

// Generate 50Mhz clock
always
begin
    #10 clk <= ~clk;
end

// Test reading from tv_mem
/*
reg [15:0] count;
always @ (posedge clk)
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
    @ (posedge clk);
    done = 0;
    while(!done)
    begin
        @ (posedge clk);
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
    @ (posedge clk);
    tx_data = char;
    uart0_wr = 1;
    @ (posedge clk);
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
            uart0_rd = 1;
            done = 1;
            @ (posedge clk);
            uart0_rd = 0;
        end
        @ (posedge clk);
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
    $display("%t: send cmd=%x",$time,tv_mem[0]);
    send_char(tv_mem[0]);

    // Send the reg_Addr
    $display("%t: send regaddr=%x",$time,tv_mem[1]);
    send_char(tv_mem[1]);

    // send data
    $display("%t: send data0=%x",$time,tv_mem[2]);
    send_char(tv_mem[2]);
    $display("%t: send data1=%x",$time,tv_mem[3]);
    send_char(tv_mem[3]);
    $display("%t: send data2=%x",$time,tv_mem[4]);
    send_char(tv_mem[4]);
    $display("%t: send data3=%x",$time,tv_mem[5]);
    send_char(tv_mem[5]);

    // Read ACK
    send_char(tv_mem[6]);
    read_char(read_ack);
    $display("%t:   recv read_ack=%x",$time,read_ack);

    $display("\n%t: END write_test",$time);
end
endtask

// Read test
task read_test;
begin
    $display("\n%t: BEGIN read_test",$time);

    // Send the command
    $display("%t: send cmd=%x",$time,tv_mem[7]);
    send_char(tv_mem[7]);

    // Send the reg_Addr
    $display("%t: send regaddr=%x",$time,tv_mem[8]);
    send_char(tv_mem[8]);

    // Read echo_cmd
    $display("%t: send dummy=%x",$time,tv_mem[9]);
    send_char(tv_mem[9]);
    read_char(echo_cmd);
    $display("%t:   recv echo_cmd=%x",$time,echo_cmd);

    // Read echo_regaddr
    $display("%t: send dummy=%x",$time,tv_mem[10]);
    send_char(tv_mem[10]);
    read_char(echo_regaddr);
    $display("%t:   recv echo_regaddr=%x",$time,echo_regaddr);

    // read the data
    $display("%t: send dummy0=%x",$time,tv_mem[11]);
    send_char(tv_mem[11]);
    read_char(read_data);
    $display("%t:   recv read_data=%x",$time,read_data);

    $display("%t: send dummy1=%x",$time,tv_mem[12]);
    send_char(tv_mem[12]);
    read_char(read_data);
    $display("%t:   recv read_data=%x",$time,read_data);

    $display("%t: send dummy2=%x",$time,tv_mem[13]);
    send_char(tv_mem[13]);
    read_char(read_data);
    $display("%t:   recv read_data=%x",$time,read_data);

    $display("%t: send dummy3=%x",$time,tv_mem[14]);
    send_char(tv_mem[14]);
    read_char(read_data);
    $display("%t:   recv read_data=%x",$time,read_data);

    $display("\n%t: END read_test",$time);
end
endtask


endmodule
