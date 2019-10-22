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
#include "hba.h"
#include "readme.h"


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // Hardware register definitions
#define HBA_BASICIO_REG_LEDS    (0)
#define HBA_BASICIO_REG_BUTTONS (1)
#define HBA_BASICIO_REG_INTR    (2)
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
    int      parent;   // Slot number of parent peripheral.
    int      coreid;   // FPGA core ID with this BASICIO
    void    *pslot;    // handle to plug-in's's slot info
    int      leds;     // most recent value to display on leds
    int      buttons;  // most recent button state
    int      intr;     // Change at input generates an interrupt
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_BASICIO;


/**************************************************************
 *  - Function prototypes
 **************************************************************/
static void usercmd(int, int, char*, SLOT*, int, int*, char*);
extern SLOT Slots[];
static void core_interrupt();


/**************************************************************
 * Initialize():  - Allocate our permanent storage and set up
 * the read/write callbacks.
 **************************************************************/
int Initialize(
    SLOT *pslot)         // points to the SLOT for this plug-in
{
    HBA_BASICIO *pctx;   // our local context
    const char  *errmsg; // error message from dlsym
    void        *reg_intr;  // use this to register and interrupt handler

    // Allocate memory for this plug-in
    pctx = (HBA_BASICIO *) malloc(sizeof(HBA_BASICIO));
    if (pctx == (HBA_BASICIO *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_basicio initialization");
        return (-1);
    }

    // Init our HBA_BASICIO structure
    pctx->parent = hba_parent();       // Slot number of parent peripheral.
    pctx->coreid = HBA_BASICIO_COREID; // Immutable.
    pctx->pslot = pslot;               // this instance of a basicio

    pctx->leds = HBA_DEFLEDS;          // most recent from to/from port
    pctx->buttons = 0xff;              // default no buttons pussed
    pctx->intr = HBA_DEFINTR;          // default interrupt enable

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
    dlerror();                  /* Clear any existing error */
    *(void **) (&(pctx->sendrecv_pkt)) = dlsym(Slots[pctx->parent].handle, "sendrecv_pkt");
    errmsg = dlerror();         /* check for errors */
    if (errmsg != NULL) {
        return(-1);
    }

    // The serial_fpga plug-in has a routine that responds to interrupts.
    // The routine polls the FPGA for its two interrupt pending registers.
    // If an interrupt bit is set the serial_fpga looks up the address of
    // core's interrupt handler and invokes it.
    // The code below registers this core's interrupt handler with
    // serial_fpga.
    dlerror();                  /* Clear any existing error */
    reg_intr = dlsym(Slots[pctx->parent].handle, "register_interrupt_handler");
    if (errmsg != NULL) {
        return(-1);
    }
    // Pass in the core ID of this plug-in...
    if (reg_intr != (void *) 0) {
        ((void (*)())reg_intr) (pctx->parent, pctx->coreid, &core_interrupt, (void *) pctx);
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
        pkt[2] = 0;                     // (cmd)
        pkt[3] = 0;                     // (reg)
        pkt[4] = 0;                     // (buttons)
        nsd = pctx->sendrecv_pkt(pctx->parent, 5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading buttons from BASICIO port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
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
        if ((ret != 1) || (nleds < 0) || (nleds > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;  // (errors are handled in calling routine)
            return;
        }
        // record the new data value 
        pctx->leds = nleds;

        // Send new value to FPGA BASICIO leds register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_LEDS;
        pkt[2] = pctx->leds;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(pctx->parent, 4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value to BASICIO leds
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;  // (errors are handled in calling routine)
            return;
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

        // Send new interrupt enable to FPGA BASICIO interrupt register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_BASICIO_REG_INTR;
        pkt[2] = pctx->intr;                    // new interrupt enable
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(pctx->parent, 4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value to BASICIO interrupt enable register
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
    }
    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


/**************************************************************
 * core_interrupt():  - interrupt handler for this peripheral
 **************************************************************/
void core_interrupt(void *trans)
{
    HBA_BASICIO *pctx;       // this hba_gpio private info
    SLOT        *pslot;      // This instance of the serial plug-in
    RSC         *prsc;       // pointer to this slot's counts resource
    int          nsd;        // number of bytes sent to FPGA
    uint8_t      pkt[HBA_MXPKT];  
    char         msg[MX_MSGLEN * 3 +1]; // text to send.  +1 for newline
    int          slen;       // length of text to output

    // get pointers to this instance of the plug-in and its slot
    pctx = (HBA_BASICIO *) trans; // transparent data is our context

    // Read value in basicio button register
    // Read one byte offset by -1 (1 -1)
    pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
    pkt[1] = HBA_BASICIO_REG_BUTTONS;
    pkt[2] = 0;                     // dummy byte
    pkt[3] = 0;                     // dummy byte
    pkt[4] = 0;                     // dummy byte

    nsd = pctx->sendrecv_pkt(pctx->parent, 5, pkt);
    // We sent header + one byte so the sendrecv return value should be 3
    if (nsd != 3) {
        // error reading value from GPIO port
        edlog("Error reading button value from basicio");
        return;
    }
    pctx->buttons = pkt[2];   // first two bytes are echo of header

    // Broadcast button value is any UI is monitoring it
    pslot = pctx->pslot;
    prsc = &(pslot->rsc[RSC_BUTTONS]);
    if (prsc->bkey != 0) {
        slen = snprintf(msg, (MX_MSGLEN -1), "%x\n", pctx->buttons);
        bcst_ui(msg, slen, &(prsc->bkey));
    }
}


// end of hba_basicio.c
