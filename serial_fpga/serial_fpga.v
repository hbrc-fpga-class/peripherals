/*
*****************************
* MODULE : serial_fpga
*
* This module implements a bridge between
* a RS232 serial interface and the
* HomeBrew Automation Bus (HBA).  It allows an
* external processor like a Raspberry Pi
* control the FPGA peripherals on the HBA Bus.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/02/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

module serial_fpga #
(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer BAUD = 32'd115_200
)
(
    // Serial Interface
    input wire rxd,
    input wire cts,
    output wire txd,
    output reg rts,
    output reg intr,

    // HBA Bus Master Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire hba_mgrant,   // Master access has be granted.
    input wire hba_xferack,  // Asserted when request has been completed.
    input wire [7:0] hba_dbus,       // The read data bus.
    output reg masterx_request,     // Requests access to the bus.
    output reg [11:0] master_abus,  // The target address. Must be zero when inactive.
    output reg master_rnw,          // 1=Read from register. 0=Write to register.
    output reg master_select,       // Transfer in progress
    output reg [7:0] master_dbus    // The write data bus.

);

/*
****************************
* Signals
****************************
*/

reg read_strobe;
reg write_strobe;
reg [7:0] tx_data;

wire rx_valid;
wire tx_busy;
wire [7:0] rx_data;

/*
****************************
* Instantiations
****************************
*/

buart # (
    .CLKFREQ(CLK_FREQUENCY)
) uart_inst (
    // inputs
   .clk(hba_clk),
   .resetq(~hba_reset),
   .baud(BAUD),    // [31:0] max = 32'd921600
   .rx(rxd),            // recv wire
   .rd(read_strobe),    // read strobe
   .wr(write_strobe),   // write strobe
   .tx_data(tx_data),   // [7:0]

   // outputs
   .tx(txd),           // xmit wire
   .valid(rx_valid),   // has recv data 
   .busy(tx_busy),     // is transmitting
   .rx_data(rx_data)   // [7:0]
);

/*
****************************
* Main
****************************
*/


// Main state machine.
reg [7:0] bridge_state;

reg [7:0] cmd_byte;

// States
localparam IDLE             = 0;
localparam REG_ADDR         = 1;
localparam READ_OP          = 2;
localparam WRITE_OP         = 3;

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        bridge_state <= IDLE;
        rts <= 0;
        intr <= 0;
        cmd_byte <= 0;
    end else begin
        case (bridge_state)
            IDLE : begin
                // Assert RTS to indicate we are ready to receive data
                rts <= 1;

                // Wait for the cmd byte
                if (rx_valid) begin
                    cmd_byte <= rx_data;
                    bridge_state <= REG_ADDR;
                end
            end
            REG_ADDR : begin
                // Wait for
            end
            READ_OP : begin
            end
            WRITE_OP : begin
            end
            default : begin
                bridge_state <= IDLE;
            end
        endcase
    end
end


endmodule

