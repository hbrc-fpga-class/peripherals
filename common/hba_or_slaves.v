/*
*****************************
* MODULE : hba_or_slaves.v
*
* This module OR's the outputs of the HBA (HomeBrew Automation)
* slave peripherals.  
*
* Hardcoded to support up to 16 slaves peripherals.
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

module hba_or_slaves #
(
    parameter integer DBUS_WIDTH = 8
)
(
    input wire [15:0] hba_xferack_slave,

    input wire [DBUS_WIDTH-1:0] hba_dbus_slave0,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave1,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave2,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave3,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave4,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave5,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave6,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave7,

    input wire [DBUS_WIDTH-1:0] hba_dbus_slave8,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave9,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave10,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave11,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave12,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave13,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave14,
    input wire [DBUS_WIDTH-1:0] hba_dbus_slave15,

    output wire hba_xferack,
    output wire [DBUS_WIDTH-1:0] hba_dbus_slave
);

// OR all the hba_xferack_slave bits together.
// Each bit represents a diffent slave;
assign hba_xferack = | hba_xferack_slave;

// OR all the hba_dbus_slave busses together
assign hba_dbus_slave = (hba_dbus_slave0 | hba_dbus_slave1 | hba_dbus_slave2 | hba_dbus_slave3) |
        (hba_dbus_slave4 | hba_dbus_slave5 | hba_dbus_slave6 | hba_dbus_slave7) |
        (hba_dbus_slave8 | hba_dbus_slave9 | hba_dbus_slave10 | hba_dbus_slave11) |
        (hba_dbus_slave12 | hba_dbus_slave13 | hba_dbus_slave14 | hba_dbus_slave15);

endmodule

