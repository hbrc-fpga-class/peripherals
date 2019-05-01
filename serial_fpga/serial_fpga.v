// Force error when implicit net has no type.
`default_nettype none

module serial_fpga #
(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer BAUD = 115_200
)
(
    input wire clk_100mhz,
    input wire reset,

    // Serial Interface
    input wire rxd,
    input wire rts,
    output wire txd,
    output wire cts,
    output wire intr,

    // HBA Bus Master Interface
    input hba_mgrant,   // Master access has be granted.
    input hba_xferack,  // Asserted when request has been completed.
    input hba_dbus[7:0],        // The read data bus.
    output masterx_request,     // Requests access to the bus.
    output master_abus[11:0],   // The target address. Must be zero when inactive.
    output master_rnw,          // 1=Read from register. 0=Write to register.
    output master_dbus[7:0]    // The write data bus.

);

endmodule

