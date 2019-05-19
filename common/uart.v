/*
*************************************

Copyright (c) 2015, James Bowman
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of swapforth nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*************************************
*/

`default_nettype none

module baudgen(
  input wire clk,
  input wire resetq,
  input wire [31:0] baud,
  input wire restart,
  output wire ser_clk);
  parameter CLKFREQ = 1000000;

  wire [38:0] aclkfreq = CLKFREQ;
  reg [38:0] d;
  wire [38:0] dInc = d[38] ? ({4'd0, baud}) : (({4'd0, baud}) - aclkfreq);
  wire [38:0] dN = restart ? 0 : (d + dInc);
  wire fastclk = ~d[38];
  assign ser_clk = fastclk;

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      d <= 0;
    end else begin
      d <= dN;
    end
  end
endmodule

/*

-----+     +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----
     |     |     |     |     |     |     |     |     |     |     |     |
     |start|  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |stop1|stop2|
     |     |     |     |     |     |     |     |     |     |     |  ?  |
     +-----+-----+-----+-----+-----+-----+-----+-----+-----+           +

*/

module uart(
   input wire clk,         // System clock
   input wire resetq,

   // Outputs
   output wire uart_busy,   // High means UART is transmitting
   output reg uart_tx,     // UART transmit wire
   // Inputs
   input wire [31:0] baud,
   input wire uart_wr_i,   // Raise to transmit byte
   input wire [7:0] uart_dat_i  // 8-bit data
);
  parameter CLKFREQ = 1000000;

  reg [3:0] bitcount;
  reg [8:0] shifter;

  assign uart_busy = |bitcount;
  wire sending = |bitcount;

  wire ser_clk;

  wire starting = uart_wr_i & ~uart_busy;
  baudgen #(.CLKFREQ(CLKFREQ)) _baudgen(
    .clk(clk),
    .resetq(resetq),
    .baud(baud),
    .restart(1'b0),
    .ser_clk(ser_clk));

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      uart_tx <= 1;
      bitcount <= 0;
      shifter <= 0;
    end else begin
      if (starting) begin
        shifter <= { uart_dat_i[7:0], 1'b0 };
        bitcount <= 1 + 8 + 1;
      end

      if (sending & ser_clk) begin
        { shifter, uart_tx } <= { 1'b1, shifter };
        bitcount <= bitcount - 4'd1;
      end
    end
  end

endmodule

module rxuart(
   input wire clk,
   input wire resetq,
   input wire [31:0] baud,
   input wire uart_rx,      // UART recv wire
   input wire rd,           // read strobe
   output wire valid,       // has data 
   output wire [7:0] data); // data
  parameter CLKFREQ = 1000000;

  reg [4:0] bitcount;
  reg [7:0] shifter;

  // On starting edge, wait 3 half-bits then sample, and sample every 2 bits thereafter

  wire idle = &bitcount;
  wire sample;
  reg [2:0] hh = 3'b111;
  wire [2:0] hhN = {hh[1:0], uart_rx};
  wire startbit = idle & (hhN[2:1] == 2'b10);
  wire [7:0] shifterN = sample ? {hh[1], shifter[7:1]} : shifter;

  wire ser_clk;
  baudgen #(.CLKFREQ(CLKFREQ)) _baudgen(
    .clk(clk),
    .baud({baud[30:0], 1'b0}),
    .resetq(resetq),
    .restart(startbit),
    .ser_clk(ser_clk));

  assign valid = (bitcount == 18);
  reg [4:0] bitcountN;
  always @*
    if (startbit)
      bitcountN = 0;
    else if (!idle & !valid & ser_clk)
      bitcountN = bitcount + 5'd1;
    else if (valid & rd)
      bitcountN = 5'b11111;
    else
      bitcountN = bitcount;

  // 3,5,7,9,11,13,15,17
  assign sample = (bitcount > 2) & bitcount[0] & !valid & ser_clk;
  assign data = shifter;

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      hh <= 3'b111;
      bitcount <= 5'b11111;
      shifter <= 0;
    end else begin
      hh <= hhN;
      bitcount <= bitcountN;
      shifter <= shifterN;
    end
  end
endmodule

module buart(
   input wire clk,
   input wire resetq,
   input wire [31:0] baud,
   input wire rx,           // recv wire
   output wire tx,          // xmit wire
   input wire rd,           // read strobe
   input wire wr,           // write strobe
   output wire valid,       // has recv data 
   output wire busy,        // is transmitting
   input wire [7:0] tx_data,
   output wire [7:0] rx_data // data
);
  parameter CLKFREQ = 1000000;

  rxuart #(.CLKFREQ(CLKFREQ)) _rx (
     .clk(clk),
     .resetq(resetq),
     .baud(baud),
     .uart_rx(rx),
     .rd(rd),
     .valid(valid),
     .data(rx_data));
  uart #(.CLKFREQ(CLKFREQ)) _tx (
     .clk(clk),
     .resetq(resetq),
     .baud(baud),
     .uart_busy(busy),
     .uart_tx(tx),
     .uart_wr_i(wr),
     .uart_dat_i(tx_data));
endmodule
