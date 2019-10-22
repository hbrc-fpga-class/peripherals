/*
 *  Name: hba_motor.c
 *
 *  Description: HomeBrew Automation (hba) 2x motor peripheral
 *
 *  Resources:
 *    mode    -  Set the motors modes.
 *    motor0  -  Power for motor0
 *    motor1  -  Power for motor1
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
 * There are three 8-bit registers.
 *
 * reg0 : Mode register. Sets the mode for both motors
 *    reg0[0] : Enable motor 0. 0=Brake, 1=Active
 *    reg0[1] : Enable motor 1. 0=Brake, 1=Active
 *    reg0[2] : Direction motor 0. 0=Forward, 1=Reverse
 *    reg0[3] : Direction motor 1. 0=Forward, 1=Reverse
 *    reg0[4] : Coast/Float motor 0. 0=Not Coast, 1=Coast
 *    reg0[5] : Coast/Float motor 1. 0=Not Coast, 1=Coast
 * reg2 : Motor 0 power and direction
 *    reg2[7:0] : Motor 0 duty cycle.  0 (stop) ... 100 (full power)
 *              Values greater than 100 are ignored.
 * reg3 : Motor 1 power and direction
 *    reg2[7:0] : Motor 1 duty cycle.  0 (stop) ... 100 (full power)
 *              Values greater than 100 are ignored.
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
#include "hba.h"
#include "readme.h"


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // hardware register definitions
#define HBA_MOTOR_REG_MODE    (0)
#define HBA_MOTOR_REG_MOTOR0  (1)
#define HBA_MOTOR_REG_MOTOR1  (2)
        // Motor control modes
#define ML_EN                 (1)
#define MR_EN                 (2)
#define ML_REV                (4)
#define MR_REV                (8)
#define ML_COAST              (16)
#define MR_COAST              (32)
        // resource names and numbers
#define FN_MODE           "mode"
#define FN_MOTOR0         "motor0"
#define FN_MOTOR1         "motor1"

#define RSC_MODE          0
#define RSC_MOTOR0        2
#define RSC_MOTOR1        3
        // What we are is a ...
#define PLUGIN_NAME        "hba_motor"
        // Default values
#define HBA_DEFMODE        0
#define HBA_DEFMODE_CHAR   'b'
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
    int      parent;   // Slot number of parent peripheral.
    int      coreid;   // FPGA core ID with this MOTOR
    void    *pslot;    // handle to plug-in's's slot info
    int      mode;     // most recent value to display on mode
    char     l_mode;   // Left mode char
    char     r_mode;   // Right mode char
    int      motor0;   // most recent motor0 value
    int      motor1;   // most recent motor. value
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
    pctx->parent = hba_parent();      // Slot number of parent peripheral.
    pctx->coreid = HBA_MOTOR_COREID;  // Immutable.
    pctx->pslot = pslot;              // this instance of a motor controller

    pctx->mode = HBA_DEFMODE;         // default mode value
    pctx->l_mode =  HBA_DEFMODE_CHAR; // default mode left char
    pctx->r_mode =  HBA_DEFMODE_CHAR; // default mode right char
    pctx->motor0 = HBA_DEFMOTOR0;     // default motor0 value.
    pctx->motor1 = HBA_DEFMOTOR1;     // default motor1 value.

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation MOTOR 2x port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_MODE].slot = pslot;
    pslot->rsc[RSC_MODE].name = FN_MODE;
    pslot->rsc[RSC_MODE].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_MODE].bkey = 0;
    pslot->rsc[RSC_MODE].pgscb = usercmd;
    pslot->rsc[RSC_MODE].uilock = -1;
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
    dlerror();                  /* Clear any existing error */
    *(void **) (&(pctx->sendrecv_pkt)) = dlsym(Slots[pctx->parent].handle, "sendrecv_pkt");
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
    char      lch;       // new left mode char
    char      rch;       // new right mode char
    int       nsd;       // number of bytes sent to FPGA
    int       ret;       // generic call return value
    uint8_t   pkt[HBA_MXPKT];

    // Get this instance of the plug-in
    pctx = (HBA_MOTOR *) pslot->priv;

    if ((cmd == EDSET) && (rscid == RSC_MODE)) {
        ret = sscanf(val, "%c%c", &lch,&rch);
        if (ret != 2) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
            return;
        }
        nval = 0;       // next mode value, Clear all bits

        // Process left mode char
        switch (lch)
        {
            case 'b' : // left brake (bit0 = 0)
                // nval =0, already brake by default
                break;
            case 'f' : // left forward (bit2 = 0)
                // forward by default, just turn off brake.
                nval = ML_EN;
                break;
            case 'r' : // left reverse (bit2 = 1)
                // Reverse and Brake off
                nval = ML_REV | ML_EN;
                break;
            case 'c' : // left coast (bit4 = 1)
                // Coast and Brake off
                nval = ML_COAST | ML_EN;
                break;
            default :
                // Invalid character
                ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
                *plen = ret;     // errors are handled in calling routine
                return;
        }

        // Process right mode char
        switch (rch)
        {
            case 'b' : // right brake (bit1 = 0)
                // nval =0, already brake by default
                break;
            case 'f' : // right forward (bit3 = 0)
                // forward by default, just turn off brake.
                nval = nval | MR_EN;
                break;
            case 'r' : // right reverse (bit3 = 1)
                // Reverse and Brake off
                nval = nval | MR_REV | MR_EN;
                break;
            case 'c' : // right coast (bit5 = 1)
                // Coast and Brake off
                nval = nval | MR_COAST | MR_EN;
                break;
            default :
                // Invalid character
                ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
                *plen = ret;     // errors are handled in calling routine
                return;
        }

        // record the new data value 
        pctx->l_mode = lch;
        pctx->r_mode = rch;
        pctx->mode = nval;

        // Send new value to FPGA MOTOR mode register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_MODE;
        pkt[2] = pctx->mode;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(pctx->parent, 4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
        }
    } else if ((cmd == EDGET) && (rscid == RSC_MODE)) {
        ret = snprintf(buf, *plen, "%c%c\n", pctx->l_mode,pctx->r_mode);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDSET) && (rscid == RSC_MOTOR0)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
            return;
        }
        if ((nval < 0) || (nval > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
            return;
        }
        // record the new data value 
        pctx->motor0 = nval;

        // Send new value to FPGA MOTOR motor0 register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_MOTOR0;
        pkt[2] = pctx->motor0;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(pctx->parent, 4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
        }
    } else if ((cmd == EDGET) && (rscid == RSC_MOTOR0)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->motor0);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDSET) && (rscid == RSC_MOTOR1)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
            return;
        }
        if ((nval < 0) || (nval > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
            return;
        }
        // record the new data value 
        pctx->motor1 = nval;

        // Send new value to FPGA MOTOR motor1 register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_MOTOR_REG_MOTOR1;
        pkt[2] = pctx->motor1;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(pctx->parent, 4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from MOTOR port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;     // errors are handled in calling routine
        }
    } else if ((cmd == EDGET) && (rscid == RSC_MOTOR0)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->motor1);
        *plen = ret;  // (errors are handled in calling routine)
    }

    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


// end of hba_motor.c
