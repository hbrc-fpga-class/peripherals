/*
*****************************
* MODULE : hba_reg_bank
*
* This module is a HBA (HomeBrew Automation) bus peripheral.
* It creates four registers that can be accessed over the bus.
*
* It is used for the development of the basic 
* HBA infrastructure.
*
* It can also be used as a template for developing
* new HBA peripherals.
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

module hba_reg_bank #
(
    // Defaults
    // DBUS_WIDTH = 8
    // ADDR_WIDTH = 12
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH,
    parameter integer PERIPH_ADDR = 0
)
(
    // HBA Bus Slave Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire hba_rnw,         // 1=Read from register. 0=Write to register.
    input wire hba_select,      // Transfer in progress.
    input wire [ADDR_WIDTH-1:0] hba_abus, // The input address bus.
    input wire [DBUS_WIDTH-1:0] hba_dbus,  // The input data bus.

    output reg [DBUS_WIDTH-1:0] hba_dbus_slave,   // The output data bus.
    output reg hba_xferack_slave,     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.

    // Access to registgers
    output reg [DBUS_WIDTH-1:0] slv_reg0,
    output reg [DBUS_WIDTH-1:0] slv_reg1,
    output reg [DBUS_WIDTH-1:0] slv_reg2,
    output reg [DBUS_WIDTH-1:0] slv_reg3,

    input wire [DBUS_WIDTH-1:0] slv_reg0_in,
    input wire [DBUS_WIDTH-1:0] slv_reg1_in,
    input wire [DBUS_WIDTH-1:0] slv_reg2_in,
    input wire [DBUS_WIDTH-1:0] slv_reg3_in,

    input wire slv_wr_en,           // Assert to set slv_reg? <= slv_reg?_in
    input wire [3:0] slv_wr_mask,   // 0001, means reg0 is writeable. etc
    input wire [3:0] slv_autoclr_mask   // 0001, means reg0 is cleared when read
);

/*
*****************************
* Signals and Assignments
*****************************
*/

wire [PERIPH_ADDR_WIDTH-1:0] periph_addr = 
    hba_abus[ADDR_WIDTH-1:ADDR_WIDTH-PERIPH_ADDR_WIDTH];

// logic to decode addresses
wire addr_decode_hit = (periph_addr == PERIPH_ADDR);
wire addr_hit_clear = ~hba_select | hba_xferack_slave;

reg addr_hit;


/*
*****************************
* Main
*****************************
*/

// Generate addr_hit
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        addr_hit <= 0;
    end else begin
        if (addr_hit_clear)
            addr_hit <= 0;
        else
            addr_hit <= addr_decode_hit;
    end
end

// state machine
reg [7:0] regbank_state;

// Define states
localparam IDLE   = 0;
localparam READ   = 1;
localparam WRITE  = 2;
localparam WAIT   = 3;

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        regbank_state <= IDLE;
        hba_xferack_slave <= 0;
        hba_dbus_slave <= 0;
        slv_reg0 <= 0;
        slv_reg1 <= 0;
        slv_reg2 <= 0;
        slv_reg3 <= 0;
    end else begin

        // Handle parent core write to registers.
        if (slv_wr_en) begin
            if (slv_wr_mask[0]) begin
                slv_reg0 <= slv_reg0_in;
            end
            if (slv_wr_mask[1]) begin
                slv_reg1 <= slv_reg1_in;
            end
            if (slv_wr_mask[2]) begin
                slv_reg2 <= slv_reg2_in;
            end
            if (slv_wr_mask[3]) begin
                slv_reg3 <= slv_reg3_in;
            end
        end

        case (regbank_state)
            IDLE : begin
                hba_xferack_slave <= 0;
                hba_dbus_slave <= 0;

                if (addr_hit)
                begin
                    if (hba_rnw)
                        regbank_state <= READ;
                    else
                        regbank_state <= WRITE;
                end
            end
            READ : begin
                hba_xferack_slave <= 1;
                regbank_state <= WAIT;
                case(hba_abus[REG_ADDR_WIDTH-1:0])
                    0 : begin
                        hba_dbus_slave <= slv_reg0;
                        if (slv_autoclr_mask[0]) begin
                            slv_reg0 <= 0;
                        end
                    end
                    1 : begin
                        hba_dbus_slave <= slv_reg1;
                        if (slv_autoclr_mask[1]) begin
                            slv_reg1 <= 0;
                        end
                    end
                    2 : begin
                        hba_dbus_slave <= slv_reg2;
                        if (slv_autoclr_mask[2]) begin
                            slv_reg2 <= 0;
                        end
                    end
                    3 : begin
                        hba_dbus_slave <= slv_reg3;
                        if (slv_autoclr_mask[3]) begin
                            slv_reg3 <= 0;
                        end
                    end
                    default : begin
                        hba_dbus_slave <= 0;
                    end
                endcase
            end
            WRITE : begin
                hba_xferack_slave <= 1;
                regbank_state <= WAIT;
                case(hba_abus[REG_ADDR_WIDTH-1:0])
                    0 : begin
                        slv_reg0 <= hba_dbus;
                    end
                    1 : begin
                        slv_reg1 <= hba_dbus;
                    end
                    2 : begin
                        slv_reg2 <= hba_dbus;
                    end
                    3 : begin
                        slv_reg3 <= hba_dbus;
                    end
                    default : ; // Do Nothing
                endcase
            end
            WAIT : begin
                regbank_state <= IDLE;
                hba_xferack_slave <= 0;
                hba_dbus_slave <= 0;
            end
            default begin
                regbank_state <= IDLE;
                hba_xferack_slave <= 0;
                hba_dbus_slave <= 0;
            end
        endcase
    end
end

endmodule
