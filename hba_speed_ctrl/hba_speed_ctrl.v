// Force error when implicit net has no type.
`default_nettype none

module hba_speed_ctrl #
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

    output wire [DBUS_WIDTH-1:0] hba_dbus_slave,   // The output data bus.
    output wire hba_xferack_slave,     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    output wire slave_interrupt,   // Send interrupt back

    // hba_speed_ctrl pins
    input wire [7:0] speed_ctrl_actual_lspeed,
    input wire [7:0] speed_ctrl_actual_rspeed,
    input wire speed_ctrl_actual_pulse,
    output wire [7:0] speed_ctrl_lpwm,
    output wire [7:0] speed_ctrl_rpwm
);

/*
*****************************
* Signals and Assignments
*****************************
*/

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_desired_lspeed;  // reg0: Desired left speed
wire [DBUS_WIDTH-1:0] reg_desired_rspeed;  // reg1: Desired right speed
wire [DBUS_WIDTH-1:0] reg_init_lpwm;       // reg2: initial left pwm
wire [DBUS_WIDTH-1:0] reg_init_rpwm;       // reg3: initial right pwm

wire slv_wr_en = speed_ctrl_actual_pulse;

assign slave_interrupt = 0;

/*
*****************************
* Instantiation
*****************************
*/

hba_reg_bank #
(
    .DBUS_WIDTH(DBUS_WIDTH),
    .PERIPH_ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .PERIPH_ADDR(PERIPH_ADDR),
    .REG_OFFSET(0)
) hba_reg_bank_inst
(
    // HBA Bus Slave Interface
    .hba_clk(hba_clk),
    .hba_reset(hba_reset),
    .hba_rnw(hba_rnw),         // 1=Read from register. 0=Write to register.
    .hba_select(hba_select),      // Transfer in progress.
    .hba_abus(hba_abus), // The input address bus.
    .hba_dbus(hba_dbus),  // The input data bus.

    .hba_dbus_slave(hba_dbus_slave),   // The output data bus.
    .hba_xferack_slave(hba_xferack_slave),     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.

    // Access to registgers
    .slv_reg0(reg_desired_lspeed),
    .slv_reg1(reg_desired_rspeed),
    // XXX .slv_reg2(reg_init_lpwm),
    // XXX .slv_reg3(reg_init_rpwm),
    
    // writeable registers
    .slv_reg2_in(speed_ctrl_actual_lspeed), // writeable by this module
    .slv_reg3_in(speed_ctrl_actual_rspeed), // writeable by this module

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b1100),    // 1100, reg 2 and reg 3 can be written by this module
    .slv_autoclr_mask(4'b0000)    // No autoclear
);



/*
*****************************
* Main
*****************************
*/



endmodule

