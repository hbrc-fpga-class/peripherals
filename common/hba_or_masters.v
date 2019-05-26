/*
*****************************
* MODULE : hba_or_masters.v
*
* This module OR's the outputs of the HBA (HomeBrew Automation)
* master peripherals.  
* 
* Hardcoded to support up to 4 master peripherals.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/25/2019
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

module hba_or_masters #
(
    parameter integer DBUS_WIDTH = 8,
    parameter integer ADDR_WIDTH = 12
)
(
    input wire [3:0] hba_rnw_master,
    input wire [3:0] hba_select_master,

    // Need to OR the slave dbus with the masters
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave,
    input wire [DBUS_WIDTH-1:0] hba_dbus_master0,
    input wire [DBUS_WIDTH-1:0] hba_dbus_master1,
    input wire [DBUS_WIDTH-1:0] hba_dbus_master2,
    input wire [DBUS_WIDTH-1:0] hba_dbus_master3,

    input wire [ADDR_WIDTH-1:0] hba_abus_master0,
    input wire [ADDR_WIDTH-1:0] hba_abus_master1,
    input wire [ADDR_WIDTH-1:0] hba_abus_master2,
    input wire [ADDR_WIDTH-1:0] hba_abus_master3,

    output wire hba_rnw,
    output wire hba_select,
    output wire [DBUS_WIDTH-1:0] hba_dbus,
    output wire [ADDR_WIDTH-1:0] hba_abus
);

// OR all the hba_rnw bits together.
// Each bit represents a diffent master;
assign hba_rnw = | hba_rnw_master;

// OR all the hba_select bits together.
// Each bit represents a diffent master;
assign hba_select = | hba_select_master;

// OR all the hba_dbus_master busses together
// along with the hba_dbus_slave
assign hba_dbus = hba_dbus_slave |
        (hba_dbus_master0 | hba_dbus_master1 | hba_dbus_master2 | hba_dbus_master3);

// OR all the hba_abus_master busses together
assign hba_abus = (hba_abus_master0 | hba_abus_master1 | hba_abus_master2 | hba_abus_master3);

endmodule

