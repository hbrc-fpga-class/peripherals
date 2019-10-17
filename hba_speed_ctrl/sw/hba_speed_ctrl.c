/*
 *  Name: hba_speed_ctrl.c
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
#define HBA_SPEED_CTRL_REG_LSPEED    (0)
#define HBA_SPEED_CTRL_REG_RSPEED    (1)
#define HBA_SPEED_CTRL_REG_LACTUAL   (2)
#define HBA_SPEED_CTRL_REG_RACTUAL   (3)
        // resource names and numbers
#define FN_LSPEED          "lspeed"
#define FN_RSPEED          "rspeed"
#define FN_ACTUAL          "acutal"
#define RSC_LSPEED        0
#define RSC_RSPEED        1
#define RSC_ACTUAL        2
        // What we are is a ...
#define PLUGIN_NAME        "hba_speed_ctrl"
        // Default led value is zero, all leds off
#define HBA_DEFLEDS        0
        // Default is no interrupt pin enabled
#define HBA_DEFINTR        0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a SPEED_CTRL port
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      lspeed;   // desired left speed
    int      rspeed;  // desired right speed
    int      lactual;     // left actual speed
    int      ractual;   // right actual speed
    int      coreid;   // FPGA core ID with this BASICIO
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_SPEED_CTRL;


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
    HBA_SPEED_CTRL *pctx;   // our local context
    const char  *errmsg; // error message from dlsym
    void        *reg_intr;  // use this to register and interrupt handler

    // Allocate memory for this plug-in
    pctx = (HBA_SPEED_CTRL *) malloc(sizeof(HBA_SPEED_CTRL));
    if (pctx == (HBA_SPEED_CTRL *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_speed_ctrl initialization");
        return (-1);
    }

    // Init our HBA_SPEED_CTRL structure
    pctx->pslot = pslot;        // this instance of a basicio
    pctx->lspeed = 0;
    pctx->rspeed = 0;
    pctx->lactual = 0;
    pctx->ractual = 0;
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation SPEED_CTRL";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_LSPEED].slot = pslot;
    pslot->rsc[RSC_LSPEED].name = FN_LSPEED;
    pslot->rsc[RSC_LSPEED].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_LSPEED].bkey = 0;
    pslot->rsc[RSC_LSPEED].pgscb = usercmd;
    pslot->rsc[RSC_LSPEED].uilock = -1;
    pslot->rsc[RSC_RSPEED].name = FN_RSPEED;
    pslot->rsc[RSC_RSPEED].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_RSPEED].bkey = 0;
    pslot->rsc[RSC_RSPEED].pgscb = usercmd;
    pslot->rsc[RSC_RSPEED].uilock = -1;
    pslot->rsc[RSC_RSPEED].slot = pslot;
    pslot->rsc[RSC_ACTUAL].name = FN_ACTUAL;
    pslot->rsc[RSC_ACTUAL].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_ACTUAL].bkey = 0;
    pslot->rsc[RSC_ACTUAL].pgscb = usercmd;
    pslot->rsc[RSC_ACTUAL].uilock = -1;
    pslot->rsc[RSC_ACTUAL].slot = pslot;

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

    // The serial_fpga plug-in has a routine that responds to interrupts.
    // The routine polls the FPGA for its two interrupt pending registers.
    // If an interrupt bit is set the serial_fpga looks up the address of
    // core's interrupt handler and invokes it.
    // The code below registers this core's interrupt handler with
    // serial_fpga.
    dlerror();                  /* Clear any existing error */
    reg_intr = dlsym(Slots[0].handle, "register_interrupt_handler");
    if (errmsg != NULL) {
        return(-1);
    }
    // pass in the slot ID (core ID) of this plug-in
    if (reg_intr != (void *) 0) {
        ((void (*)())reg_intr) (pslot->slot_id, &core_interrupt, (void *) pctx);
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
    HBA_SPEED_CTRL *pctx;  // hba_speed_ctrl private info
    int       new_lspeed=0;   // new leds value for BASICIO pins
    // Does not make sense to set the button value
    // XXX int       nbuttons=0;   // new buttons value: for BASICIO pins
    int       nintr=0;  // new interrupt enable setting for pins
    int       nsd;      // number of bytes sent to FPGA
    int       ret;      // generic call return value
    uint8_t   pkt[HBA_MXPKT];  

    // Get this instance of the plug-in
    pctx = (HBA_SPEED_CTRL *) pslot->priv;


    if ((cmd == EDSET) && (rscid == RSC_LSPEED)) {
        ret = sscanf(val, "%d", &new_lspeed);
        if ((ret != 1) || (new_lspeed < 0) || (new_lspeed > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;  // (errors are handled in calling routine)
            return;
        }
        // record the new data value 
        pctx->lspeed = new_lspeed;

        // Send new value to FPGA BASICIO leds register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_SPEED_CTRL_REG_LSPEED;
        pkt[2] = pctx->lspeed;                     // new value
        pkt[3] = 0;                                // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value to BASICIO leds
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;  // (errors are handled in calling routine)
            return;
        }
    } else if ((cmd == EDGET) && (rscid == RSC_LSPEED)) {
        // Read value in FPGA BASICIO value register
        pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_SPEED_CTRL_REG_LSPEED;
        pkt[2] = 0;                     // (cmd)
        pkt[3] = 0;                     // (reg)
        pkt[4] = 0;                     // (lspeed)
        nsd = pctx->sendrecv_pkt(5, pkt);
        // We sent header + one byte so the sendrecv return value should be 3
        if (nsd != 3) {
            // error reading buttons from BASICIO port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got value.  Print and send to user
            pctx->lspeed = pkt[2];   // first two bytes are echo of header
            ret = snprintf(buf, *plen, "%d\n", pctx->lspeed);
            *plen = ret;  // (errors are handled in calling routine)
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
    HBA_SPEED_CTRL *pctx;       // this hba_gpio private info
    SLOT        *pslot;      // This instance of the serial plug-in
    RSC         *prsc;       // pointer to this slot's counts resource
    int          nsd;        // number of bytes sent to FPGA
    uint8_t      pkt[HBA_MXPKT];  
    char         msg[MX_MSGLEN * 3 +1]; // text to send.  +1 for newline
    int          slen;       // length of text to output

    // get pointers to this instance of the plug-in and its slot
    pctx = (HBA_SPEED_CTRL *) trans; // transparent data is our context

    // Read value in basicio button register
    // Read one byte offset by -1 (1 -1)
    pkt[0] = HBA_READ_CMD | ((1 -1) << 4) | pctx->coreid;
    pkt[1] = HBA_SPEED_CTRL_REG_LACTUAL;
    pkt[2] = 0;                     // dummy byte
    pkt[3] = 0;                     // dummy byte
    pkt[4] = 0;                     // dummy byte

    nsd = pctx->sendrecv_pkt(5, pkt);
    // We sent header + one byte so the sendrecv return value should be 3
    if (nsd != 3) {
        // error reading value from GPIO port
        edlog("Error reading button value from basicio");
        return;
    }
    pctx->lactual = pkt[2];   // first two bytes are echo of header

    // Broadcast button value is any UI is monitoring it
    pslot = pctx->pslot;
    prsc = &(pslot->rsc[RSC_ACTUAL]);
    if (prsc->bkey != 0) {
        slen = snprintf(msg, (MX_MSGLEN -1), "%x\n", pctx->lactual);
        bcst_ui(msg, slen, &(prsc->bkey));
    }
}


// end of hba_speed_ctrl.c
