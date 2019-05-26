/*
*****************************
* MODULE : hba_arbiter
*
* This module implements an arbiter for
* HBA (HomeBrew Automation) master peripherals.
*
* It support up to 4 master peripherals.
* If a master wants access to the bus
* it asserts its hba_mrequest[x] line.
* The aribiter grants access by asserting
* the corresponding hba_mgrant[x] line.
*
* The lower index hba_mrequest lines
* have higher priority.
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


module hba_arbiter
(
    input wire hba_clk,
    input wire hba_reset,

    input wire hba_select,      // indicates active master
    input wire [3:0] hba_mrequest,
    output reg [3:0] hba_mgrant
);

always @ (posedge hba_clk)
begin
    if (hba_reset) begin
        hba_mgrant <= 0;
    end else begin
        // Is a master active?
        if (hba_select | hba_mgrant) begin
            // Yes. Turn of all grants.
            hba_mgrant <= 0;
        end else begin
            // No. Master active. We can choose one.
            // Lowest index has priority.
            if (hba_mrequest[0]) begin
                hba_mgrant[0] <= 1;
            end else if (hba_mrequest[1]) begin
                hba_mgrant[1] <= 1;
            end else if (hba_mrequest[2]) begin
                hba_mgrant[2] <= 1;
            end else if (hba_mrequest[3]) begin
                hba_mgrant[3] <= 1;
            end
        end
    end
end

endmodule

