/*
 * Name: eedd.h
 *
 * Description: This file contains the define's and data structures for use
 *              in the empty event-driven daemon.
 *
 * Copyright:   Copyright (C) 2019 by Demand Peripherals, Inc.
 *              All rights reserved.
 *
 * License:     This program is free software; you can redistribute it and/or
 *              modify it under the terms of the Version 2 of the GNU General
 *              Public License as published by the Free Software Foundation.
 *              GPL2.txt in the top level directory is a copy of this license.
 *              This program is distributed in the hope that it will be useful,
 *              but WITHOUT ANY WARRANTY; without even the implied warranty of
 *              MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *              GNU General Public License for more details.
 *
 */

#ifndef HBA_H_
#define HBA_H_


/***************************************************************************
 *  - Defines
 ***************************************************************************/
#define HBA_PARENT_NAME    "serial_fpga"

        // Number of possible FPGA cores (peripherals)
#define NCORE              16

        // Immutable Hardware Core IDs.
#define HBA_BASICIO_COREID 1
#define HBA_QTR_COREID     2
#define HBA_MOTOR_COREID   3
#define HBA_SONAR_COREID   4
#define HBA_QUAD_COREID    5
#define HBA_GPIO_COREID    6

        // Maximum size of input/output string
#define MX_MSGLEN          120
        // HBA protocol defines
#define HBAERROR_NOSEND   (-1)
#define HBAERROR_NORECV   (-2)
#define HBA_READ_CMD      (0x80)
#define HBA_WRITE_CMD     (0x00)
#define HBA_MXPKT         (16)
#define HBA_ACK           (0xAC)

/***************************************************************************
 *  - Functions
 ***************************************************************************/

// Find most recently added FPGA slot number...
int hba_parent(){

    extern SLOT Slots[];

    for (int i = MX_PLUGIN; i >= 0; i--) {
        if (Slots[i].name != 0) {
            if (!strcmp(Slots[i].name, HBA_PARENT_NAME)) {
                return i;
	    }
	}
    }

    edlog("ERROR: Parent %s must be loaded before children.", HBA_PARENT_NAME);
    return 0;
}

#endif /*HBA_H*/

