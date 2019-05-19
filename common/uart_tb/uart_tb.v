/*
*****************************
* MODULE : uart_tb
*
* Testbench for the uart module.
*
* Author : Brandon Bloodget
* Create Date : 05/05/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps

module uart_tb;

// Parameters
parameter integer CLK_FREQUENCY = 100_000_000;
parameter integer BAUD = 32'd115_200;
parameter integer TEST_VECTOR_WIDTH = 23;

// Inputs (registers)
reg clk;
reg reset;
reg rxd;
reg uart0_rd;
reg uart0_wr;
reg [7:0] tx_data;

reg baudgen_restart;

// Outputs (wires)
wire txd;
wire rx_valid;
wire tx_busy;
wire [7:0] rx_data;

wire ser_clk;

// Internal wires

// Testbench rxd data
// Test data is 0xAA, 0xBB with start and stop bits added
reg [TEST_VECTOR_WIDTH-1:0] tv_data = 23'b11_1011_1011_011_1010_1010_01;

// Expected results
localparam [7:0] rx_data_ok1 = 8'hAA;
localparam [7:0] rx_data_ok2 = 8'hBB;

/*
*****************************
* Instantiations
*****************************
*/

baudgen # (
    .CLKFREQ(CLK_FREQUENCY)
) baudgen_inst (
  .clk(clk),
  .resetq(~reset),
  .baud(BAUD),
  .restart(baudgen_restart),
  .ser_clk(ser_clk)
);

buart # (
    .CLKFREQ(CLK_FREQUENCY)
) dut (
    // inputs
   .clk(clk),
   .resetq(~reset),
   .baud(BAUD),    // [31:0]
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
*****************************
* Main
*****************************
*/
initial begin
    $dumpfile("uart.vcd");
    $dumpvars(0, uart_tb);
    clk = 0;
    reset = 0;
    rxd = 0;
    uart0_rd = 0;
    uart0_wr = 0;
    tx_data = 0;

    baudgen_restart = 0;

    // Wait 100ns
    #100;
    // Add stimulus here
    @(posedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    baudgen_restart = 1;
    @(posedge clk);
    baudgen_restart = 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
end

// Count clock between ticks
reg [9:0] clk_count;
reg [9:0] clks_per_tick;
always @ (posedge clk)
begin
    if (reset) begin
        clk_count <= 0;
    end else begin
        if (ser_clk) begin
            clks_per_tick <= clk_count;
            clk_count <= 1;
        end else begin
            clk_count <= clk_count + 1;
        end
    end
end

// Drive the rxd line
reg [9:0] bit_count = 0;
always @ (posedge ser_clk) begin
    rxd <= tv_data[0];
    tv_data[TEST_VECTOR_WIDTH-1:0] <= {1'b1, tv_data[TEST_VECTOR_WIDTH-2:1]};
    bit_count <= bit_count + 1;
end

// register rx_valid to find edges
reg rx_valid_reg;
wire rx_valid_posedge = rx_valid & ~rx_valid_reg;
always @ (posedge clk)
begin
    if (reset) begin
        rx_valid_reg <= 0;
    end else begin
        rx_valid_reg <= rx_valid;
    end
end

// Check the results
reg [7:0] tb_count;
reg final_send;
always @ (posedge clk) begin
    if (reset) begin
        tb_count <= 0;
        final_send <= 0;
        uart0_rd <= 0;
    end else begin
        if (rx_valid_posedge) begin
            uart0_rd <= 1;
            tb_count <= tb_count + 1;
            case (tb_count)
                0 : begin
                    if (rx_data == rx_data_ok1) begin
                        $display("rx_data: %x, expected: %x, PASS",rx_data,rx_data_ok1);
                    end else begin
                        $display("rx_data: %x, expected: %x, FAIL",rx_data,rx_data_ok1);
                    end
                end
                1 : begin
                    final_send <= 1;
                    if (rx_data == rx_data_ok2) begin
                        $display("rx_data: %x, expected: %x, PASS",rx_data,rx_data_ok2);
                    end else begin
                        $display("rx_data: %x, expected: %x, FAIL",rx_data,rx_data_ok2);
                    end
                    $display("CLK_FREQUENCY: %d, BAUD: %d",CLK_FREQUENCY,BAUD);
                    $display("clks_per_tick: %d",clks_per_tick);
                end
                default : begin
                    $display("rx_data: %x, expected: NONE, FAIL",rx_data);
                end
            endcase
        end else begin
            // not rx_valid
            uart0_rd <= 0;
        end
    end
end

// Wait for finish
reg [9:0] extra_clocks;
reg final_send2;
always @ (posedge clk) 
begin
    if (reset) begin
        extra_clocks <= 1000;
        final_send2 <= 0;
    end else begin
        final_send2 <= final_send;
        if (final_send2) begin
            extra_clocks <= extra_clocks - 1;
            if (extra_clocks == 0) begin
                $finish;
            end
        end
    end
end

// Generate a 100mhz clk
always begin
    #5 clk <= ~clk;
end

endmodule

