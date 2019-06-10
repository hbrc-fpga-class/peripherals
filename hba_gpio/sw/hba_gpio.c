/*
 *  Name: hba_gpio.c
 *
 *  Description: HomeBrew Automation (hba) quad gpio peripheral
 *
 *  Resources:
 *    val    -  current value at the four GPIO pins
 *    dir    -  GPIO data direction. 1==output, default==input
 *    intr   -  change on input pin causes an interrupt
 */

/*
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
 */

/*
 * FPGA Register Interface
 * There are three 8-bit registers. Since the module only controls 4 GPIOs
 * only the lower 4-bit of each register is active.
 *   reg0: Direction Register(reg_dir) (a.k.a out_en).  1=output, 0=input.
 *   reg1: Pins Register(reg_pins). read or write the value of the pins.
 *   reg2: Interrupt Register(reg_intr_en). 1 == interrupt enabled on pin.
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
#include "../include/eedd.h"
#include "readme.h"

#define HBAERROR_NOSEND   (-1)
#define HBAERROR_NORECV   (-2)
#define HBA_READ_CMD      (0x80)
#define HBA_WRITE_CMD     (0x00)
#define HBA_MXPKT         (16)
#define HBA_GPIO_REG_DIR  (0)
#define HBA_GPIO_REG_VAL  (1)
#define HBA_GPIO_REG_INTR (2)
#define HBA_ACK           (0xAC)


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // resource names and numbers
#define FN_VAL             "val"
#define FN_DIR             "dir"
#define FN_INTR            "intr"
#define RSC_VAL            0
#define RSC_DIR            1
#define RSC_INTR           2
        // What we are is a ...
#define PLUGIN_NAME        "hba_gpio"
        // Default data direction is zero, is all inputs
#define HBA_DEFDIR         0
        // Default is no interrupt pin enabled
#define HBA_DEFINTR        0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a GPIO port
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      val;      // most recent value on gpio pins
    int      dir;      // GPIO data direction. 1==output
    int      intr;     // Change at input generates an interrupt
    int      coreid;   // FPGA core ID with this GPIO
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_GPIO;


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
    HBA_GPIO *pctx;    // our local context
    const char *errmsg; // error message from dlsym

    // Allocate memory for this plug-in
    pctx = (HBA_GPIO *) malloc(sizeof(HBA_GPIO));
    if (pctx == (HBA_GPIO *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_gpio initialization");
        return (-1);
    }

    // Init our HBA_GPIO structure
    pctx->val = 0;             // most recent from to/from port
    pctx->dir = HBA_DEFDIR;    // default data direction rate
    pctx->intr = HBA_DEFINTR;  // default interrupt enable
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation quad GPIO port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_VAL].slot = pslot;
    pslot->rsc[RSC_VAL].name = FN_VAL;
    pslot->rsc[RSC_VAL].flags = IS_READABLE | IS_WRITABLE | CAN_BROADCAST;
    pslot->rsc[RSC_VAL].bkey = 0;
    pslot->rsc[RSC_VAL].pgscb = usercmd;
    pslot->rsc[RSC_VAL].uilock = -1;
    pslot->rsc[RSC_DIR].name = FN_DIR;
    pslot->rsc[RSC_DIR].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_DIR].bkey = 0;
    pslot->rsc[RSC_DIR].pgscb = usercmd;
    pslot->rsc[RSC_DIR].uilock = -1;
    pslot->rsc[RSC_DIR].slot = pslot;
    pslot->rsc[RSC_INTR].name = FN_INTR;
    pslot->rsc[RSC_INTR].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_INTR].bkey = 0;
    pslot->rsc[RSC_INTR].pgscb = usercmd;
    pslot->rsc[RSC_INTR].uilock = -1;
    pslot->rsc[RSC_INTR].slot = pslot;

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
    HBA_GPIO *pctx;     // hba_gpio private info
    int       nval=0;   // new value for GPIO pins
    int       ndir=0;   // new direction for GPIO pins
    int       nintr=0;  // new interrupt enable setting for pins
    int       nsd;      // number of bytes sent to FPGA
    int       ret;      // generic call return value
    uint8_t   pkt[HBA_MXPKT];  

    // Get this instance of the plug-in
    pctx = (HBA_GPIO *) pslot->priv;


    if ((cmd == EDGET) && (rscid == RSC_VAL)) {
        // Read value in FPGA GPIO value register
        pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_GPIO_REG_VAL;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading value from GPIO port
            edlog("Error reading GPIO value from FPGA");
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got value.  Print and send to user
            pctx->val = pkt[2];   // first two bytes are echo of header
            ret = snprintf(buf, *plen, "%x\n", pctx->val);
            *plen = ret;  // (errors are handled in calling routine)
        }
    }
    else if ((cmd == EDGET) && (rscid == RSC_DIR)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->dir);
        *plen = ret;  // (errors are handled in calling routine)
    }
    if ((cmd == EDGET) && (rscid == RSC_INTR)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->intr);
        *plen = ret;  // (errors are handled in calling routine)
    }
    else if ((cmd == EDSET) && (rscid == RSC_VAL)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nval < 0) || (nval > 0x0f)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->val = nval;

        // Send new value to FPGA GPIO value register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_GPIO_REG_VAL;
        pkt[2] = pctx->val;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from GPIO port
            edlog("Error writing GPIO value to FPGA");
        }
    }
    else if ((cmd == EDSET) && (rscid == RSC_DIR)) {
        ret = sscanf(val, "%x", &ndir);
        if ((ret != 1) || (ndir < 0) || (ndir > 0x0f)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // record the new data direction 
        pctx->dir = ndir;

        // Send new direction to FPGA GPIO direction register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_GPIO_REG_DIR;
        pkt[2] = pctx->dir;                     // new direction
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from GPIO port
            edlog("Error writing GPIO direction to FPGA");
        }
    }
    else if ((cmd == EDSET) && (rscid == RSC_INTR)) {
        ret = sscanf(val, "%x", &nintr);
        if ((ret != 1) || (nintr < 0) || (nintr > 0x0f)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // record the new interrupt enable configuration
        pctx->intr = nintr;

        // Send new interrupt enable to FPGA GPIO interrupt register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_GPIO_REG_INTR;
        pkt[2] = pctx->intr;                    // new interrupt enable
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from GPIO port
            edlog("Error writing GPIO direction to FPGA");
        }
    }
    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


// end of hba_gpio.c
