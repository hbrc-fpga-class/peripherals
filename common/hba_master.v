/*
*****************************
* MODULE : hba_master
*
* This module implements an hba_master
* state machine.  It has a simple
* "app" interface for initiating hba bus
* transfers.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/05/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

module hba_master #
(
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    // Default ADDR_WIDTH = 12
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH
)
(
    // App interface
    input wire [PERIPH_ADDR_WIDTH-1:0] app_core_addr,
    input wire [REG_ADDR_WIDTH-1:0] app_reg_addr,
    input wire [DBUS_WIDTH-1:0] app_data_in,
    input wire app_rnw,
    input wire app_en_strobe,    // rising edge start state machine
    output reg [DBUS_WIDTH-1:0] app_data_out,
    output reg app_valid_out,    // read or write transfer complete. Assert one clock cycle.

    // HBA Bus Master Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire hba_mgrant,   // Master access has be granted.
    input wire hba_xferack,  // Asserted when request has been completed.
    input wire [DBUS_WIDTH-1:0] hba_dbus,       // The read data bus.
    output wire master_request,     // Requests access to the bus.
    output reg [ADDR_WIDTH-1:0] master_abus,  // The target address. Must be zero when inactive.
    output reg master_rnw,         // 1=Read from register. 0=Write to register.
    output reg master_select,      // Transfer in progress
    output reg [DBUS_WIDTH-1:0] master_dbus    // The write data bus.

);

/*
****************************
* Assignment
****************************
*/

// When app assert app_en_strobe request access to the mba bus
// from the mba_arbiter.
assign master_request = app_en_strobe && (hba_state == IDLE);


/*
****************************
* Main
****************************
*/


// HBA Master State Machine
reg [7:0] hba_state;

reg [PERIPH_ADDR_WIDTH-1:0] app_core_addr_reg;
reg [REG_ADDR_WIDTH-1:0] app_reg_addr_reg;
reg [DBUS_WIDTH:0] app_data_in_reg;
reg app_rnw_reg;

// States
localparam IDLE         = 0;
localparam GRANT_WAIT   = 1;
localparam XFER_WAIT    = 2;

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        hba_state <= IDLE;
        master_abus <= 0;
        master_rnw <= 0;
        master_select <= 0;
        master_dbus <= 0;

        app_core_addr_reg <= 0;
        app_reg_addr_reg <= 0;
        app_data_in_reg <= 0;
        app_rnw_reg <= 0;

        app_data_out <= 0;
        app_valid_out <= 0;
    end else begin
        case (hba_state)
            IDLE : begin
                master_abus <= 0;
                master_rnw <= 0;
                master_select <= 0;
                master_dbus <= 0;
                app_valid_out <= 0;
                if (app_en_strobe) begin
                    // register the inputs
                    app_core_addr_reg <= app_core_addr;
                    app_reg_addr_reg <= app_reg_addr;
                    app_data_in_reg <= app_data_in;
                    app_rnw_reg <= app_rnw;
                    hba_state <= GRANT_WAIT;
                end
            end
            GRANT_WAIT : begin
                if (hba_mgrant) begin
                    // Access Granted. Place data on bus
                    master_abus <= {app_core_addr_reg, app_reg_addr_reg};
                    master_rnw <= app_rnw_reg;
                    master_dbus <= (app_rnw_reg) ? 0 : app_data_in_reg ;
                    master_select <= 1;
                    hba_state <= XFER_WAIT;
                end
            end
            XFER_WAIT : begin
                if (hba_xferack) begin
                    // Slave replied the xfer has been completed
                    app_data_out <= (app_rnw_reg) ? hba_dbus : 0;
                    app_valid_out <= 1;
                    master_select <= 0;
                    hba_state <= IDLE;
                end
            end
            default : begin
                hba_state <= IDLE;
            end
        endcase
    end
end

endmodule

