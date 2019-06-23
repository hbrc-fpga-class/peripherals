/*
 *  Name: hba_motor.c
 *
 *  Description: HomeBrew Automation (hba) 2x motor peripheral
 *
 *  Resources:
 *    ctrl    -  Enables/Disables motors
 *    float   -  Sets float/coast mode
 *    motor0  -  Power and direction for motor0
 *    motor1  -  Power and direction for motor1
 */

/*
 * Copyright:   Copyright (C) 2019 by Demand Peripherals, Inc.
 *              All rights reserved.
 *
 *              Copyright (C) 2019 by Brandon Blodget <brandon.blodget@gmail.com>
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
 */

/*
 * FPGA Register Interface
 * There are four 8-bit registers.
 * reg0 : Control register. Enables motors
 *    reg0[0] : Enable motor 0.
 *    reg0[1] : Enable motor 1.
 * reg1 : Float register
 * reg2 : Set power and direction for motor0
 * reg2 : Set power and direction for motor1
 */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <syslog.h>
#include <errno.h>
#include <string.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <limits.h>              // for PATH_MAX
#include <termios.h>
#include <dlfcn.h>
#include "eedd.h"
#include "readme.h"

#define HBAERROR_NOSEND         (-1)
#define HBAERROR_NORECV         (-2)
#define HBA_READ_CMD            (0x80)
#define HBA_WRITE_CMD           (0x00)
#define HBA_MXPKT               (16)
#define HBA_ACK                 (0xAC)

#define HBA_MOTOR_REG_CTRL    (0)
#define HBA_MOTOR_REG_FLOAT   (1)
#define HBA_MOTOR_REG_MOTOR0  (2)
#define HBA_MOTOR_REG_MOTOR1  (3)


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // resource names and numbers
#define FN_CTRL           "ctrl"
#define FN_FLOAT          "float"
#define FN_MOTOR0         "motor0"
#define FN_MOTOR1         "motor1"

#define RSC_CTRL          0
#define RSC_FLOAT         1
#define RSC_MOTOR0        2
#define RSC_MOTOR1        3
        // What we are is a ...
#define PLUGIN_NAME        "hba_motor"
        // Default values
#define HBA_DEFCTRL        0
#define HBA_DEFFLOAT       0
#define HBA_DEFMOTOR0      0
#define HBA_DEFMOTOR1      0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a MOTOR port
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      ctrl;     // most recent value to display on ctrl
    int      coast;    // most recent "float" value
    int      motor0;   // most recent motor0 value
    int      motor1;   // most recent motor. value
    int      coreid;   // FPGA core ID with this MOTOR
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_MOTOR;


/**************************************************************
 *  - Function prototypes
 **************************************************************/
static void usercmd(int, int, char*, SLOT*, int, int*, char*);
extern SLOT Slots[];


/**************************************************************
 * Initialize():  - Allocate our permanent storage and set up
 * the read/write callbacks.
 **************************************************************/
int Initialize(
    SLOT *pslot)       // points to the SLOT for this plug-in
{
    HBA_MOTOR *pctx;  // our local context
    const char *errmsg; // error message from dlsym

    // Allocate memory for this plug-in
    pctx = (HBA_MOTOR *) malloc(sizeof(HBA_MOTOR));
    if (pctx == (HBA_MOTOR *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_motor initialization");
        return (-1);
    }

    // Init our HBA_MOTOR structure
    pctx->ctrl = HBA_DEFCTRL;       // default ctrl value
    pctx->coast = HBA_DEFFLOAT;     // default coast value
    pctx->motor0 = HBA_DEFMOTOR0;   // default motor0 value.
    pctx->motor1 = HBA_DEFMOTOR1;   // default motor1 value.
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation MOTOR 2x port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_CTRL].slot = pslot;
    pslot->rsc[RSC_CTRL].name = FN_CTRL;
    pslot->rsc[RSC_CTRL].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_CTRL].bkey = 0;
    pslot->rsc[RSC_CTRL].pgscb = usercmd;
    pslot->rsc[RSC_CTRL].uilock = -1;
    pslot->rsc[RSC_FLOAT].name = FN_FLOAT;
    pslot->rsc[RSC_FLOAT].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_FLOAT].bkey = 0;
    pslot->rsc[RSC_FLOAT].pgscb = usercmd;
    pslot->rsc[RSC_FLOAT].uilock = -1;
    pslot->rsc[RSC_FLOAT].slot = pslot;
    pslot->rsc[RSC_MOTOR0].name = FN_MOTOR0;
    pslot->rsc[RSC_MOTOR0].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_MOTOR0].bkey = 0;
    pslot->rsc[RSC_MOTOR0].pgscb = usercmd;
    pslot->rsc[RSC_MOTOR0].uilock = -1;
    pslot->rsc[RSC_MOTOR0].slot = pslot;
    pslot->rsc[RSC_MOTOR1].name = FN_MOTOR1;
    pslot->rsc[RSC_MOTOR1].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_MOTOR1].bkey = 0;
    pslot->rsc[RSC_MOTOR1].pgscb = usercmd;
    pslot->rsc[RSC_MOTOR1].uilock = -1;
    pslot->rsc[RSC_MOTOR1].slot = pslot;

    // The serial_fpga plug-in has a routine to send packets to the FPGA
    // and to return with packet data from the FPGA.  We need to look up
    // this, 'sendrecv_pkt', address from within serial_fpga.so.
    // We cache the routine address so we don't need to look it up every
    // time we want to send a packet.
    // Note the assumption that serial_fpga.so is always in slot 0.
    dlerror();                  /* Clear any existing error */
    *(void **) (&(pctx->sendrecv_pkt)) = dlsym(Slots[0].handle, "sendrecv_pkt");
    errmsg = dlerror();         /* check for errors */
    if (errmsg != NULL) {
        return(-1);
    }

    return (0);
}


/**************************************************************
 * usercmd():  - The user is reading or setting a resource
 **************************************************************/
void usercmd(
    int       cmd,      //==EDGET if a read, ==EDSET on write
    int       rscid,    // ID of resource being accessed
    char     *val,      // new value for the resource
    SLOT     *pslot,    // pointer to slot info.
    int       cn,       // Index into UI table for requesting conn
    int      *plen,     // size of buf on input, #char in buf on output
    char     *buf)
{
    HBA_MOTOR *pctx;     // hba_motor private info
    int       nval=0;    // new value to write to reg
    int       nsd;       // number of bytes sent to FPGA
    int       ret;       // generic call return value
    uint8_t   pkt[HBA_MXPKT];

    // Get this instance of the plug-in
    pctx = (HBA_MOTOR *) pslot->priv;

    if ((cmd == EDSET) && (rscid == RSC_CTRL)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nval < 0) || (nval > 0x03)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->ctrl = nval;

        // Send new value to FPGA MOTOR ctrl register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_CTRL;
        pkt[2] = pctx->ctrl;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            edlog("Error writing MOTOR ctrl to FPGA");
        }
    } else if ((cmd == EDGET) && (rscid == RSC_CTRL)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->ctrl);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDSET) && (rscid == RSC_FLOAT)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nval < 0) || (nval > 0x03)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->coast = nval;

        // Send new value to FPGA MOTOR coast register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_FLOAT;
        pkt[2] = pctx->coast;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            edlog("Error writing MOTOR coast to FPGA");
        }
    } else if ((cmd == EDGET) && (rscid == RSC_CTRL)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->coast);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDSET) && (rscid == RSC_MOTOR0)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nval < 0) || (nval > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->motor0 = nval;

        // Send new value to FPGA MOTOR motor0 register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_MOTOR0;
        pkt[2] = pctx->motor0;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            edlog("Error writing MOTOR motor0 to FPGA");
        }
    } else if ((cmd == EDGET) && (rscid == RSC_MOTOR0)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->motor0);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDSET) && (rscid == RSC_MOTOR1)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nval < 0) || (nval > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->motor1 = nval;

        // Send new value to FPGA MOTOR motor1 register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_MOTOR1;
        pkt[2] = pctx->motor1;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            edlog("Error writing MOTOR motor1 to FPGA");
        }
    } else if ((cmd == EDGET) && (rscid == RSC_MOTOR0)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->motor1);
        *plen = ret;  // (errors are handled in calling routine)
    }

    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


// end of hba_motor.c
