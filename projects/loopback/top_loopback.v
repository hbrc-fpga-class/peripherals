/*
********************************************
* MODULE top_loopback.v
*
* This project is a test of the uart.
* It reads a character from the rx side
* of the uart then sends it on the tx side.
*
* Target Board: TinyFPGA BX
*
* Author: Brandon Blodget
* Create Date: 05/16/2019
*
********************************************
*/

// Force error when implicit net has no type.
`default_nettype none

module top_loopback
(
    input wire  CLK_16MHZ,

    // serial connection
    input wire  PIN_9,  // rxd
    output wire PIN_10,  // txd

    // pwm connections (turn off motors)
    output wire PIN_5,  // pwml
    output wire PIN_8,  // pwmr

    // debug (leds) outputs
    output wire PIN_18,  // loop_state (led0)
    output wire PIN_19,  // echo txd   (led1)
    output wire PIN_26,   // echo rxd   (led2)

    output wire PIN_20,   // (led3)
    output wire PIN_29,   // (led4)
    output wire PIN_21,   // (led5)
    output wire PIN_30,   // (led6)
    output wire PIN_22   // (led7)

);

// Parameters
parameter integer CLK_FREQUENCY = 60_000_000;
parameter integer BAUD = 32'd115_200;

/*
********************************************
* Signals
********************************************
*/

wire clk_60mhz;
wire locked;
wire rxd;
wire txd;

reg reset = 0;
reg [7:0] count = 0;

reg uart_rd;
reg uart_wr;
wire rx_valid;
wire tx_busy;

wire [7:0] rx_data;
reg [7:0] tx_data;

assign rxd = PIN_9;
assign PIN_10 = txd;

// debug
assign PIN_18 = loop_state;
assign PIN_19 = ~txd;
assign PIN_26 = ~rxd;

// turn off motors
assign PIN_5 = 0;  // pwml
assign PIN_8 = 0;  // pwmr


// Turn off other leds
assign PIN_20 = 0;   // (led3)
assign PIN_29 = 0;   // (led4)
assign PIN_21 = 0;   // (led5)
assign PIN_30 = 0;   // (led6)
assign PIN_22 = 0;   // (led7)

/*
****************************
* Instantiations
****************************
*/

// Use PLL to get 60mhz clock
pll_60mhz pll_60mhz_inst (
    .clock_in(CLK_16MHZ),
    .clock_out(clk_60mhz),
    .locked(locked)
);

buart # (
    .CLKFREQ(CLK_FREQUENCY)
) uart_inst (
   .clk(clk_60mhz),
   .resetq(~reset),
   .baud(BAUD),
   .rx(rxd),           // recv wire
   .tx(txd),          // xmit wire
   .rd(uart_rd),           // read strobe
   .wr(uart_wr),           // write strobe
   .valid(rx_valid),       // has recv data 
   .busy(tx_busy),        // is transmitting
   .tx_data(tx_data),
   .rx_data(rx_data) // data
);

/*
****************************
* Main
****************************
*/

// Hold reset on power up then release.
// ice40 sets all registers to zero on power up.
// Holding reset will set to default values.
always @ (posedge clk_60mhz)
begin
    if (count < 10) begin
        reset <= 1;
        count <= count + 1;
    end else begin
        reset <= 0;
    end
end

// loopback
reg loop_state;
localparam RECV_CHAR = 0;
localparam SEND_CHAR = 1;
always @ (posedge clk_60mhz)
begin
    if (reset) begin
        uart_rd <= 0;
        uart_wr <= 0;
        tx_data <= 0;
        loop_state <= 0;
    end else begin
        case (loop_state)
            RECV_CHAR : begin
                uart_rd <= 0;
                uart_wr <= 0;
                if (rx_valid) begin
                    uart_rd <= 1;
                    tx_data <= rx_data;
                    loop_state <= SEND_CHAR;
                end
            end
            SEND_CHAR : begin
                uart_rd <= 0;
                if (~tx_busy) begin
                    uart_wr <= 1;
                    loop_state <= RECV_CHAR;
                end
            end
            default : begin
            end
        endcase
    end
end

endmodule

