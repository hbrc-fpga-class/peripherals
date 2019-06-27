/*
*****************************
* MODULE : hba_master_tbc
*
* This module implements a HomeBrew Automation Bus (HBA)
* master peripheral.  This master peripheral 
* is a statemachine that does the HBRC Tablebot
* challenge phase 1.
*
* This is an example of writing an application without a processor.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 06/26/2019
*
*****************************
*/

/*
*****************************
*
* Copyright (C) 2019 by Brandon Blodget <brandon.blodget@gmail.com>
* All rights reserved.
*
* License:
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none


module hba_master_tbc #
(
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH
)
(
    // HBA Bus Master Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire [DBUS_WIDTH-1:0] hba_dbus,  // The input data bus.

    input wire hba_xferack,  // Asserted when request has been completed.
    input wire hba_mgrant,   // Master access has be granted.
    output wire hba_mrequest,     // Requests access to the bus.
    output wire [ADDR_WIDTH-1:0] hba_abus_master,  // The target address. Must be zero when inactive.
    output wire hba_rnw_master,          // 1=Read from register. 0=Write to register.
    output wire hba_select_master,       // Transfer in progress
    output wire [DBUS_WIDTH-1:0] hba_dbus_master    // The write data bus.

    // Tablebot pins
    // XXX input wire tb_en
);

/*
****************************
* Signals
****************************
*/

// App hba_master interface
reg [PERIPH_ADDR_WIDTH-1:0] app_core_addr;
reg [REG_ADDR_WIDTH-1:0] app_reg_addr;
reg [DBUS_WIDTH-1:0] app_data_in;
reg app_rnw;
reg app_en_strobe;    // rising edge start state machine
wire [DBUS_WIDTH-1:0] app_data_out;
wire app_valid_out;    // read or write transfer complete. Assert one clock cycle.

reg start;
reg [DBUS_WIDTH-1:0] qtr0;
reg [DBUS_WIDTH-1:0] qtr1;

/*
****************************
* Instantiations
****************************
*/

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
    .hba_mrequest(hba_mrequest),     // Requests access to the bus.
    .hba_abus_master(hba_abus_master),  // The target address. Must be zero when inactive.
    .hba_rnw_master(hba_rnw_master),         // 1=Read from register. 0=Write to register.
    .hba_select_master(hba_select_master),      // Transfer in progress
    .hba_dbus_master(hba_dbus_master)    // The write data bus.
);

/*
****************************
* Main
****************************
*/

// The Tablebot challenge statemachine

// Peripheral Slots
localparam TBC_SLOT                 = 0;
localparam BASICIO_SLOT             = 1;
localparam QTR_SLOT                 = 2;
localparam MOTOR_SLOT               = 3;
localparam SONAR_SLOT               = 4;

// States
reg [31:0] tb_state;
localparam IDLE                     = 0;
localparam SETUP_BASICIO            = 1;
localparam SETUP_QTR                = 2;
localparam SETUP_MOTOR0             = 3;
localparam SETUP_MOTOR1             = 4;
localparam SETUP_MOTOR_MODE_FF      = 5;
localparam READ_QTR0                = 6;
localparam READ_QTR1                = 7;
localparam SETUP_MOTOR_MODE_BB      = 8;
localparam DONE                     = 9;


always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        tb_state <= IDLE;

        app_core_addr <= 0;
        app_reg_addr <= 0;
        app_data_in <= 0;
        app_rnw <= 0;
        app_en_strobe <= 0;
        qtr0 <= 0;
        qtr1 <= 0;
    end else begin
        case (tb_state)
            IDLE : begin
                if (start) begin
                    tb_state <= SETUP_BASICIO;
                end
            end
            SETUP_BASICIO : begin
                // turn on led
                app_core_addr <= BASICIO_SLOT;
                app_reg_addr <= 0;  // reg0 = leds
                app_data_in <= 1;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= SETUP_QTR;
                end
            end
            SETUP_QTR : begin
                // ctrl 3
                app_core_addr <= QTR_SLOT;
                app_reg_addr <= 0;  // reg0 = ctrl
                app_data_in <= 3;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= SETUP_MOTOR0;
                end
            end
            SETUP_MOTOR0 : begin
                // motor0 0x10
                app_core_addr <= MOTOR_SLOT;
                app_reg_addr <= 1;  // reg1 = motor0
                app_data_in <= 8'h10;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= SETUP_MOTOR1;
                end
            end
            SETUP_MOTOR1 : begin
                // motor0 0x10
                app_core_addr <= MOTOR_SLOT;
                app_reg_addr <= 2;  // reg2 = motor1
                app_data_in <= 8'h10;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= SETUP_MOTOR_MODE_FF;
                end
            end
            SETUP_MOTOR_MODE_FF : begin
                // mode 0x03
                app_core_addr <= MOTOR_SLOT;
                app_reg_addr <= 0;  // reg0 = mode
                app_data_in <= 8'h03;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= READ_QTR0;
                end
            end
            READ_QTR0 : begin
                // read reg1 qtr0
                app_core_addr <= QTR_SLOT;
                app_reg_addr <= 1;  // reg1 = qtr0
                app_rnw <= 1;       // read_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    qtr0 <= app_data_out;
                    app_en_strobe <= 0;
                    if (app_data_out == 8'hff) begin
                        // edge detected
                        tb_state <= SETUP_MOTOR_MODE_BB;
                    end else begin
                        tb_state <= READ_QTR1;
                    end
                end
            end
            READ_QTR1 : begin
                // read reg2 qtr1
                app_core_addr <= QTR_SLOT;
                app_reg_addr <= 2;  // reg2 = qtr1
                app_rnw <= 1;       // read_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    qtr1 <= app_data_out;
                    app_en_strobe <= 0;
                    if (app_data_out == 8'hff) begin
                        // edge detected
                        tb_state <= SETUP_MOTOR_MODE_BB;
                    end else begin
                        tb_state <= READ_QTR0;
                    end
                end
            end
            SETUP_MOTOR_MODE_BB : begin
                // mode 0x00
                app_core_addr <= MOTOR_SLOT;
                app_reg_addr <= 0;  // reg0 = mode
                app_data_in <= 8'h00;
                app_rnw <= 0;       // write_op
                app_en_strobe <= 1;
                if (app_valid_out) begin
                    app_en_strobe <= 0;
                    tb_state <= DONE;
                end
            end
            DONE : begin
                tb_state <= tb_state;
            end
            default : begin
                tb_state <= IDLE;
            end
        endcase
    end
end

// Delay the start of statemachine
reg [31:0] count;
always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        count <= 0;
        start <= 0;
    end else begin
        if (count == 15_000_000) begin
            start <= 1;
        end else begin
            count <= count + 1;
        end
    end
end


endmodule

