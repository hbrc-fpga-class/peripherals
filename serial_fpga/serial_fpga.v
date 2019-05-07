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
    input wire hba_xferack,  // Asserted when request has been completed.
    input wire [DBUS_WIDTH-1:0] hba_dbus,       // The read data bus.
    // FIXME: handling the hba mgrant in this module for now
    // XXX input wire hba_mgrant,   // Master access has be granted.
    // XXX output reg master_request,     // Requests access to the bus.
    output wire [ADDR_WIDTH-1:0] master_abus,  // The target address. Must be zero when inactive.
    output wire master_rnw,          // 1=Read from register. 0=Write to register.
    output wire master_select,       // Transfer in progress
    output wire [DBUS_WIDTH-1:0] master_dbus    // The write data bus.

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

// FIXME: Simple aribiter in this module for now.
reg hba_mgrant;
wire master_request;

// App hba_master interface
reg [PERIPH_ADDR_WIDTH-1:0] app_core_addr;
reg [REG_ADDR_WIDTH-1:0] app_reg_addr;
reg [DBUS_WIDTH-1:0] app_data_in;
reg app_rnw;
reg app_en_strobe;    // rising edge start state machine
wire [DBUS_WIDTH-1:0] app_data_out;
wire app_valid_out;    // read or write transfer complete. Assert one clock cycle.

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

hba_master #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
) hba_master_inst
(
    // App interface
    .app_core_addr(app_core_addr),
    .app_reg_addr(app_reg_addr),
    .app_data_in(app_data_in),
    .app_rnw(app_rnw),
    .app_en_strobe(app_en_strobe),  // rising edge start state machine
    .app_data_out(app_data_out),
    .app_valid_out(app_valid_out),  // read or write transfer complete. Assert one clock cycle.

    // HBA Bus Master Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_mgrant(hba_mgrant),   // Master access has be granted.
    .hba_xferack(hba_xferack),  // Asserted when request has been completed.
    .hba_dbus(hba_dbus),       // The read data bus.
    .master_request(master_request),     // Requests access to the bus.
    .master_abus(master_abus),  // The target address. Must be zero when inactive.
    .master_rnw(master_rnw),         // 1=Read from register. 0=Write to register.
    .master_select(master_select),      // Transfer in progress
    .master_dbus(master_dbus)    // The write data bus.

);

/*
****************************
* Main
****************************
*/

// A simple Arbiter.  We only have 1 master for now
// so always grant access.
// FIXME : Move this to top level or into it own module.
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        hba_mgrant <= 0;
    end else begin
        hba_mgrant <= master_request;
    end
end

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
reg [2:0] transfer_num;

// States
localparam IDLE                     = 0;
localparam REG_ADDR                 = 1;
localparam READ_ECHO_CMD            = 2;
localparam READ_ECHO_CMD_WAIT       = 3;
localparam READ_ECHO_RAD            = 4;
localparam READ_ECHO_RAD_WAIT       = 5;
localparam READ_TRANSFER            = 6;

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
        transfer_num <= 0;
    end else begin
        case (serial_state)
            IDLE : begin
                // Assert RTS to indicate we are ready to receive data
                rts <= 1;
                uart0_rd <= 0;
                uart0_wr <= 0;
                transfer_num <= 0;

                // Wait for the cmd byte
                if (rx_valid_posedge) begin
                    uart0_rd <= 1;
                    cmd_byte <= rx_data;
                    transfer_num <= rx_data[3:1];
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
                    serial_state <= READ_TRANSFER;
                end
            end
            READ_TRANSFER : begin
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

