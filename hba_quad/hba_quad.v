
// Force error when implicit net has no type.
`default_nettype none

module hba_quad #
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

    // hba_quad pins
    input wire [1:0] quad_enc_a,
    input wire [1:0] quad_enc_b
);

/*
*****************************
* Params, Signals and Assignments
*****************************
*/

localparam LEFT     = 0;
localparam RIGHT    = 1;

// Define the bank of registers
wire [DBUS_WIDTH-1:0] reg_ctrl;  // reg0: Control register

wire [DBUS_WIDTH-1:0] reg_qtr0_in;  // reg1: qtr0 value
wire [DBUS_WIDTH-1:0] reg_qtr1_in;  // reg2: qtr1 value

wire [DBUS_WIDTH-1:0] reg_period;  // reg3: Trigger period


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
    .PERIPH_ADDR(PERIPH_ADDR)
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
    .slv_reg0(reg_ctrl),
    //.slv_reg1(),  
    //.slv_reg2(),
    .slv_reg3(reg_period),
    
    // TODO : Add these later
    // XXX .slv_reg3(reg_delay0),
    // XXX .slv_reg4(reg_delay1),
    // XXX .slv_reg5(reg_period),

    // writeable registers
    .slv_reg1_in(reg_qtr0_in),
    .slv_reg2_in(reg_qtr1_in),

    .slv_wr_en(slv_wr_en),   // Assert to set slv_reg? <= slv_reg?_in
    .slv_wr_mask(4'b0110),    // 0010, means reg1,reg2 is writeable.
    .slv_autoclr_mask(4'b0000)    // No autoclear
);

// Left Encoder

wire left_pulse;
wire left_dir;

quadrature left_quad_inst
(
    .clk(hba_clk),
    .reset(hba_reset),

    // hba_quad input pins
    .quad_enc_a(quad_enc_a[LEFT]),
    .quad_enc_b(quad_encb[LEFT]),

    // outputs
    .enc_out(left_pulse),
    .enc_dir(left_dir)
);

pulse_counter left_counter_inst
(
    .clk(hba_clk),
    .reset(hba_reset),
    .en(),

    .pulse_in(left_pulse),
    .dir_in(left_dir),

    .count(),   // [15:0]
    .valid()
);



endmodule


