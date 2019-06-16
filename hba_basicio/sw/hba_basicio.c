/*
 *  Name: hba_basicio.c
 *
 *  Description: HomeBrew Automation (hba) basicio (leds and buttons) peripheral
 *
 *  Resources:
 *    leds    -  value displayed on the leds (read/write)
 *    buttons -  value from the buttons (read only)
 *    intr    -  0=no button interrupts, 1=enable button interrupts (read/write)
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
 *   reg0 : (reg_led) - The value to write to the LEDs.
 *   reg1 : (reg_button_in) - The buttons value.
 *   reg2 : (reg_intr_en) - Interrupt Enable Register. A value of 1 indicates that
 *          change in button state will cause an interrupt.
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
#define HBA_BASICIO_REG_LEDS    (0)
#define HBA_BASICIO_REG_BUTTONS (1)
#define HBA_BASICIO_REG_INTR    (2)
#define HBA_ACK                 (0xAC)


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // resource names and numbers
#define FN_LEDS            "leds"
#define FN_BUTTONS         "buttons"
#define FN_INTR            "intr"
#define RSC_LEDS           0
#define RSC_BUTTONS        1
#define RSC_INTR           2
        // What we are is a ...
#define PLUGIN_NAME        "hba_basicio"
        // Default led value is zero, all leds off
#define HBA_DEFLEDS        0
        // Default is no interrupt pin enabled
#define HBA_DEFINTR        0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a BASICIO port
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      leds;     // most recent value to display on leds
    int      buttons;  // most recent button state
    int      intr;     // Change at input generates an interrupt
    int      coreid;   // FPGA core ID with this BASICIO
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_BASICIO;


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
    HBA_BASICIO *pctx;  // our local context
    const char *errmsg; // error message from dlsym

    // Allocate memory for this plug-in
    pctx = (HBA_BASICIO *) malloc(sizeof(HBA_BASICIO));
    if (pctx == (HBA_BASICIO *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_basicio initialization");
        return (-1);
    }

    // Init our HBA_BASICIO structure
    pctx->leds = HBA_DEFLEDS;   // most recent from to/from port
    pctx->buttons = 0xff;    // default no buttons pussed
    pctx->intr = HBA_DEFINTR;  // default interrupt enable
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation BASICIO led/button port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_LEDS].slot = pslot;
    pslot->rsc[RSC_LEDS].name = FN_LEDS;
    pslot->rsc[RSC_LEDS].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_LEDS].bkey = 0;
    pslot->rsc[RSC_LEDS].pgscb = usercmd;
    pslot->rsc[RSC_LEDS].uilock = -1;
    pslot->rsc[RSC_BUTTONS].name = FN_BUTTONS;
    pslot->rsc[RSC_BUTTONS].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_BUTTONS].bkey = 0;
    pslot->rsc[RSC_BUTTONS].pgscb = usercmd;
    pslot->rsc[RSC_BUTTONS].uilock = -1;
    pslot->rsc[RSC_BUTTONS].slot = pslot;
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
    HBA_BASICIO *pctx;  // hba_basicio private info
    int       nleds=0;   // new leds value for BASICIO pins
    // Does not make sense to set the button value
    // XXX int       nbuttons=0;   // new buttons value: for BASICIO pins
    int       nintr=0;  // new interrupt enable setting for pins
    int       nsd;      // number of bytes sent to FPGA
    int       ret;      // generic call return value
    uint8_t   pkt[HBA_MXPKT];  

    // Get this instance of the plug-in
    pctx = (HBA_BASICIO *) pslot->priv;


    if ((cmd == EDGET) && (rscid == RSC_BUTTONS)) {
        // Read value in FPGA BASICIO value register
        pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_BUTTONS;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading buttons from BASICIO port
            edlog("Error reading BASICIO buttons from FPGA");
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got value.  Print and send to user
            pctx->buttons = pkt[2];   // first two bytes are echo of header
            ret = snprintf(buf, *plen, "%x\n", pctx->buttons);
            *plen = ret;  // (errors are handled in calling routine)
        }
    }
    else if ((cmd == EDGET) && (rscid == RSC_LEDS)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->leds);
        *plen = ret;  // (errors are handled in calling routine)
    }
    if ((cmd == EDGET) && (rscid == RSC_INTR)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->intr);
        *plen = ret;  // (errors are handled in calling routine)
    }
    else if ((cmd == EDSET) && (rscid == RSC_LEDS)) {
        ret = sscanf(val, "%x", &nleds);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        if ((nleds < 0) || (nleds > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            return;
        }
        // record the new data value 
        pctx->leds = nleds;

        // Send new value to FPGA BASICIO leds register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_LEDS;
        pkt[2] = pctx->leds;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from BASICIO port
            edlog("Error writing BASICIO leds to FPGA");
        }
    }
    // Does not make sense to set the button value
    /*
    else if ((cmd == EDSET) && (rscid == RSC_BUTTONS)) {
        ret = sscanf(val, "%x", &nbuttons);
        if ((ret != 1) || (nbuttons < 0) || (nbuttons > 0x0f)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // record the new data direction 
        pctx->buttons = nbuttons;

        // Send new direction to FPGA BASICIO direction register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_BUTTONS;
        pkt[2] = pctx->buttons;                     // new direction
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from BASICIO port
            edlog("Error writing BASICIO direction to FPGA");
        }
    }
    */
    else if ((cmd == EDSET) && (rscid == RSC_INTR)) {
        ret = sscanf(val, "%x", &nintr);
        if ((ret != 1) || (nintr < 0) || (nintr > 0x0f)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // record the new interrupt enable configuration
        pctx->intr = nintr;

        // Send new interrupt enable to FPGA BASICIO interrupt register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_INTR;
        pkt[2] = pctx->intr;                    // new interrupt enable
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from BASICIO port
            edlog("Error writing BASICIO intr to FPGA");
        }
    }
    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


// end of hba_basicio.c
