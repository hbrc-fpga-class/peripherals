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
    parameter integer BAUD = 32'd115_200,

    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    // Default ADDR_WIDTH = 12
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH
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
    input wire [DBUS_WIDTH-1:0] hba_dbus,       // The read data bus.
    output reg master_request,     // Requests access to the bus.
    output reg [ADDR_WIDTH-1:0] master_abus,  // The target address. Must be zero when inactive.
    output reg master_rnw,          // 1=Read from register. 0=Write to register.
    output reg master_select,       // Transfer in progress
    output reg [DBUS_WIDTH-1:0] master_dbus    // The write data bus.

);

/*
****************************
* Signals
****************************
*/

reg uart0_rd;
reg uart0_wr;
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
****************************
* Main
****************************
*/

// register rx_valid to find edges
reg rx_valid_reg;
wire rx_valid_posedge = rx_valid & ~rx_valid_reg;
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        rx_valid_reg <= 0;
    end else begin
        rx_valid_reg <= rx_valid;
    end
end

// Serial Interface State Machine.
reg [7:0] serial_state;

reg [7:0] cmd_byte;
reg [7:0] regaddr_byte;

// States
localparam IDLE                     = 0;
localparam REG_ADDR                 = 1;
localparam READ_ECHO_CMD            = 2;
localparam READ_ECHO_CMD_WAIT       = 3;
localparam READ_ECHO_RAD            = 4;
localparam READ_ECHO_RAD_WAIT       = 5;

localparam WRITE_OP    = 15;

localparam READ             = 1;

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        serial_state <= IDLE;
        rts <= 0;
        intr <= 0;
        cmd_byte <= 0;
        regaddr_byte <= 0;
        uart0_rd <= 0;
        uart0_wr <= 0;
    end else begin
        case (serial_state)
            IDLE : begin
                // Assert RTS to indicate we are ready to receive data
                rts <= 1;
                uart0_rd <= 0;
                uart0_wr <= 0;

                // Wait for the cmd byte
                if (rx_valid_posedge) begin
                    uart0_rd <= 1;
                    cmd_byte <= rx_data;
                    serial_state <= REG_ADDR;
                end
            end
            REG_ADDR : begin
                uart0_rd <= 0;
                // Wait for regAddr byte
                if (rx_valid_posedge) begin
                    uart0_rd <= 1;
                    regaddr_byte <= rx_data;
                    if (cmd_byte[0] == READ) begin
                        serial_state <= READ_ECHO_CMD;
                    end else begin
                        serial_state <= WRITE_OP;
                    end
                end
            end
            READ_ECHO_CMD : begin
                // Echo back the command
                uart0_rd <= 0;
                uart0_wr <= 0;
                if (cts == 1) begin
                    tx_data <= cmd_byte;
                    uart0_wr <= 1;
                    serial_state <= READ_ECHO_CMD_WAIT;
                end
            end
            READ_ECHO_CMD_WAIT : begin
                // Wait for the send to complete
                uart0_rd <= 0;
                uart0_wr <= 0;
                if (!tx_busy && rx_valid) begin
                    // Finished tx and received dummy byte
                    uart0_rd <= 1;
                    serial_state <= READ_ECHO_RAD;
                end
            end
            READ_ECHO_RAD : begin
                // Echo back the Reg ADdr
                uart0_rd <= 0;
                uart0_wr <= 0;
                if (cts == 1) begin
                    tx_data <= regaddr_byte;
                    uart0_wr <= 1;
                    serial_state <= READ_ECHO_RAD_WAIT;
                end
            end
            READ_ECHO_RAD_WAIT : begin
                // Wait for the send to complete
                uart0_rd <= 0;
                uart0_wr <= 0;
                if (!tx_busy && rx_valid) begin
                    // Finished tx and received dummy byte
                    uart0_rd <= 1;
                    // XXX serial_state <= READ_ECHO_RAD_WAIT;
                end
            end




            WRITE_OP : begin
            end
            default : begin
                serial_state <= IDLE;
            end
        endcase
    end
end


endmodule

