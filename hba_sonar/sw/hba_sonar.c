/*
 *  Name: hba_sonar.c
 *
 *  Description: HomeBrew Automation (hba) 2x sonar peripheral
 *
 *  Resources:
 *    ctrl    -  Enables/Disables sonars
 *    sonar0  -  Read the last sonar0 value.
 *    sonar1  -  Read the last sonar1 value.
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
 * reg0 : Control register. Enables sonars and interrupts.
 *    reg0[0] : Enable sonar 0.
 *    reg0[1] : Enable sonar 1.
 * reg1 : Last Sonar 0 value
 * reg2 : Last Sonar 1 value
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

#define HBA_SONAR_REG_CTRL    (0)
#define HBA_SONAR_REG_SONAR0  (1)
#define HBA_SONAR_REG_SONAR1  (2)


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // resource names and numbers
#define FN_CTRL           "ctrl"
#define FN_SONAR0         "sonar0"
#define FN_SONAR1         "sonar1"
#define RSC_CTRL          0
#define RSC_SONAR0        1
#define RSC_SONAR1        2
        // What we are is a ...
#define PLUGIN_NAME        "hba_sonar"
        // Default value is zero, sonars disabled
#define HBA_DEFCTRL        0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a SONAR port
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      ctrl;     // most recent value to display on ctrl
    int      sonar0;   // most recent sonar0 value
    int      sonar1;   // most recent sonar1 value
    int      coreid;   // FPGA core ID with this SONAR
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_SONAR;


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
    HBA_SONAR *pctx;  // our local context
    const char *errmsg; // error message from dlsym

    // Allocate memory for this plug-in
    pctx = (HBA_SONAR *) malloc(sizeof(HBA_SONAR));
    if (pctx == (HBA_SONAR *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_sonar initialization");
        return (-1);
    }

    // Init our HBA_SONAR structure
    pctx->ctrl = HBA_DEFCTRL;   // most recent from to/from port
    pctx->sonar0 = 0;    // default sonar0 value.
    pctx->sonar1 = 0;    // default sonar1 value.
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation SONAR 2x port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_CTRL].slot = pslot;
    pslot->rsc[RSC_CTRL].name = FN_CTRL;
    pslot->rsc[RSC_CTRL].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_CTRL].bkey = 0;
    pslot->rsc[RSC_CTRL].pgscb = usercmd;
    pslot->rsc[RSC_CTRL].uilock = -1;
    pslot->rsc[RSC_SONAR0].name = FN_SONAR0;
    pslot->rsc[RSC_SONAR0].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_SONAR0].bkey = 0;
    pslot->rsc[RSC_SONAR0].pgscb = usercmd;
    pslot->rsc[RSC_SONAR0].uilock = -1;
    pslot->rsc[RSC_SONAR0].slot = pslot;
    pslot->rsc[RSC_SONAR1].name = FN_SONAR1;
    pslot->rsc[RSC_SONAR1].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_SONAR1].bkey = 0;
    pslot->rsc[RSC_SONAR1].pgscb = usercmd;
    pslot->rsc[RSC_SONAR1].uilock = -1;
    pslot->rsc[RSC_SONAR1].slot = pslot;

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
    HBA_SONAR *pctx;     // hba_sonar private info
    int       nctrl=0;   // new ctrl value for SONAR pins
    int       nsd;       // number of bytes sent to FPGA
    int       ret;       // generic call return value
    uint8_t   pkt[HBA_MXPKT];

    // Get this instance of the plug-in
    pctx = (HBA_SONAR *) pslot->priv;

    if ((cmd == EDSET) && (rscid == RSC_CTRL)) {
        ret = sscanf(val, "%x", &nctrl);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nctrl < 0) || (nctrl > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->ctrl = nctrl;

        // Send new value to FPGA SONAR ctrl register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_SONAR_REG_CTRL;
        pkt[2] = pctx->ctrl;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from SONAR port
            edlog("Error writing SONAR ctrl to FPGA");
        }
    } else if ((cmd == EDGET) && (rscid == RSC_CTRL)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->ctrl);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDGET) && (rscid == RSC_SONAR0)) {
        // Read value in FPGA SONAR0 value register
        pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_SONAR_REG_SONAR0;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading sonar0 from SONAR port
            edlog("Error reading SONAR sonar0 from FPGA");
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got value.  Print and send to user
            pctx->sonar0 = pkt[2];   // first two bytes are echo of header
            // XXX ret = snprintf(buf, *plen, "%f\n", ((float)pctx->sonar0)*0.55);
            ret = snprintf(buf, *plen, "%x\n", pctx->sonar0);
            *plen = ret;  // (errors are handled in calling routine)
        }
    } else if ((cmd == EDGET) && (rscid == RSC_SONAR1)) {
        // Read value in FPGA SONAR1 value register
        pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_SONAR_REG_SONAR1;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading sonar1 from SONAR port
            edlog("Error reading SONAR sonar1 from FPGA");
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got value.  Print and send to user
            pctx->sonar1 = pkt[2];   // first two bytes are echo of header
            ret = snprintf(buf, *plen, "%x\n", pctx->sonar1);
            *plen = ret;  // (errors are handled in calling routine)
        }
    }

    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


// end of hba_sonar.c
