/*
 *  Name: hba_quad.c
 *
 *  Description: HomeBrew Automation (hba) 2x quadrature peripheral
 *
 *  Resources:
 *    ctrl      -  Enables/Disables updating encoder counts and interrupt.
 *    enc0      -  Reads 16-bit left encoder value
 *    enc1      -  Reads 16-bit right encoder value
 *    enc       -  Reads left and right encoder values
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
 * reg0 : Control register. Enables quad enc updates and interrupts.
 *  - reg0[0] : Enable left encoder register updates
 *  - reg0[1] : Enable right encoder register updates
 *  - reg0[2] : Enable interrupt.
 * reg1 : Left encoder count, least significant byte
 * reg2 : Left encoder count, most significant byte
 * reg3 : Right encoder count, least significant byte
 * reg4 : Right encoder count, most significant byte
 *
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
#define HBA_QUAD_REG_CTRL       (0)
#define HBA_QUAD_REG_ENC0_LSB   (1)
#define HBA_QUAD_REG_ENC0_MSB   (2)
#define HBA_QUAD_REG_ENC1_LSB   (3)
#define HBA_QUAD_REG_ENC1_MSB   (4)
        // resource names and numbers
#define FN_CTRL         "ctrl"
#define FN_ENC0         "enc0"
#define FN_ENC1         "enc1"
#define FN_ENC          "enc"

#define RSC_CTRL        0
#define RSC_ENC0        1
#define RSC_ENC1        2
#define RSC_ENC         3

        // What we are is a ...
#define PLUGIN_NAME        "hba_quad"
        // Default value is zero, for all resources
#define HBA_DEFVAL        0
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of a QUAD port
typedef struct
{
    void    *pslot;     // handle to plug-in's's slot info
    int      ctrl;      // most recent value to display on ctrl
    int      enc0;      // most recent enc0 value
    int      enc1;      // most recent enc1 value
    int      coreid;    // FPGA core ID with this QUAD
    int      (*sendrecv_pkt)();  // routine to send data to the FPGA
} HBA_QUAD;


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
    SLOT *pslot)           // points to the SLOT for this plug-in
{
    HBA_QUAD   *pctx;      // our local context
    const char *errmsg;    // error message from dlsym
    void       *reg_intr;  // use this to register and interrupt handler

    // Allocate memory for this plug-in
    pctx = (HBA_QUAD *) malloc(sizeof(HBA_QUAD));
    if (pctx == (HBA_QUAD *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in hba_quad initialization");
        return (-1);
    }

    // Init our HBA_QUAD structure
    pctx->pslot = pslot;        // this instance of a quadrature decoder
    pctx->ctrl = HBA_DEFVAL;    // most recent from to/from port
    pctx->enc0 = HBA_DEFVAL;    // default enc0 value.
    pctx->enc1 = HBA_DEFVAL;    // default enc1 value.
    // The following assumes that plug-ins are loaded in the
    // order they appear in the FPGA.  This is the first thing
    // to check when things go wrong.
    pctx->coreid = pslot->slot_id;

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "HomeBrew Automation QUAD 2x port";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_CTRL].slot = pslot;
    pslot->rsc[RSC_CTRL].name = FN_CTRL;
    pslot->rsc[RSC_CTRL].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_CTRL].bkey = 0;
    pslot->rsc[RSC_CTRL].pgscb = usercmd;
    pslot->rsc[RSC_CTRL].uilock = -1;
    pslot->rsc[RSC_ENC0].name = FN_ENC0;
    pslot->rsc[RSC_ENC0].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_ENC0].bkey = 0;
    pslot->rsc[RSC_ENC0].pgscb = usercmd;
    pslot->rsc[RSC_ENC0].uilock = -1;
    pslot->rsc[RSC_ENC0].slot = pslot;
    pslot->rsc[RSC_ENC1].name = FN_ENC1;
    pslot->rsc[RSC_ENC1].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_ENC1].bkey = 0;
    pslot->rsc[RSC_ENC1].pgscb = usercmd;
    pslot->rsc[RSC_ENC1].uilock = -1;
    pslot->rsc[RSC_ENC1].slot = pslot;
    pslot->rsc[RSC_ENC].name = FN_ENC;
    pslot->rsc[RSC_ENC].flags = IS_READABLE | CAN_BROADCAST;
    pslot->rsc[RSC_ENC].bkey = 0;
    pslot->rsc[RSC_ENC].pgscb = usercmd;
    pslot->rsc[RSC_ENC].uilock = -1;
    pslot->rsc[RSC_ENC].slot = pslot;

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
    HBA_QUAD *pctx;      // hba_quad private info
    int       nval=0;   // new value for a register
    int       nsd;      // number of bytes sent to FPGA
    int       ret;      // generic call return value
    uint8_t   pkt[HBA_MXPKT];

    // Get this instance of the plug-in
    pctx = (HBA_QUAD *) pslot->priv;

    if ((cmd == EDSET) && (rscid == RSC_CTRL)) {
        ret = sscanf(val, "%x", &nval);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        if ((nval < 0) || (nval > 0xff)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // record the new data value 
        pctx->ctrl = nval;

        // Send new value to FPGA QUAD ctrl register
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
    } else if ((cmd == EDGET) && (rscid == RSC_CTRL)) {
        ret = snprintf(buf, *plen, "%x\n", pctx->ctrl);
        *plen = ret;  // (errors are handled in calling routine)
    } else if ((cmd == EDGET) && (rscid == RSC_ENC0)) {

        // Disable left encoder updates
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl & 0xfe;     // bit0 (en left enc) set to 0.
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }

        // Read value in FPGA ENC0 value register
        pkt[0] = HBA_READ_CMD | ((2 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_ENC0_LSB;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        pkt[5] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(6, pkt);
        // We sent header + two bytes so the sendrecv return value should be 4
        if (nsd != 4) {
            // error reading enc0 from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got the values.  Print and send to user
            // First two bytes are echoed header.
            pctx->enc0 = (pkt[3]<<8) | pkt[2];   // Reconstruct 16-bit value.
            ret = snprintf(buf, *plen, "%04x\n", pctx->enc0);
            *plen = ret;  // (errors are handled in calling routine)
        }

        // Put the control back the way it was.
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl;
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
    } else if ((cmd == EDGET) && (rscid == RSC_ENC1)) {
        // Disable right encoder updates
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl & 0xfd;     // bit1 (en right enc) set to 0.
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }

        // Read value in FPGA ENC1 value register
        pkt[0] = HBA_READ_CMD | ((2 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_ENC1_LSB;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        pkt[5] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(6, pkt);
        // We sent header + two bytes so the sendrecv return value should be 4
        if (nsd != 4) {
            // error reading enc1 from QUAD port
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got the values.  Print and send to user
            // First two bytes are echoed header.
            pctx->enc1 = (pkt[3]<<8) | pkt[2];   // Reconstruct 16-bit value.
            ret = snprintf(buf, *plen, "%04x\n", pctx->enc1);
            *plen = ret;  // (errors are handled in calling routine)
        }

        // Put the control back the way it was.
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl;
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
    } else if ((cmd == EDGET) && (rscid == RSC_ENC)) {

        // Disable both encoder updates
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl & 0xfc;     // Both encoders updates disabled
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }

        // Read both enc0 and enc1 values.  4 registers in all
        pkt[0] = HBA_READ_CMD | ((4 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_ENC0_LSB;
        pkt[2] = 0;                     // dummy byte
        pkt[3] = 0;                     // dummy byte
        pkt[4] = 0;                     // dummy byte
        pkt[5] = 0;                     // dummy byte
        pkt[6] = 0;                     // dummy byte
        pkt[7] = 0;                     // dummy byte
        nsd = pctx->sendrecv_pkt(8, pkt);
        // We sent 2 byte header + four bytes so the sendrecv return value should be 6
        if (nsd != 6) {
            // error reading enc1 from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }
        else {
            // Got the values.  Print and send to user
            // First two bytes are echoed header.
            pctx->enc0 = (pkt[3]<<8) | pkt[2];   // Reconstruct enc0 16-bit value.
            pctx->enc1 = (pkt[5]<<8) | pkt[4];   // Reconstruct enc1 16-bit value.
            ret = snprintf(buf, *plen, "%04x %04x\n", pctx->enc0, pctx->enc1);
            *plen = ret;  // (errors are handled in calling routine)
        }

        // Put the control back the way it was.
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | pctx->coreid;
        pkt[1] = HBA_QUAD_REG_CTRL;
        pkt[2] = pctx->ctrl;
        pkt[3] = 0;                     // dummy for the ack
        nsd = pctx->sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from QUAD port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
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
    HBA_QUAD    *pctx;       // this peripheral's private info
    SLOT        *pslot;      // This instance of the serial plug-in
    RSC         *prsc;       // pointer to this slot's counts resource
    int          nsd;        // number of bytes sent to FPGA
    uint8_t      pkt[HBA_MXPKT];  
    char         msg[MX_MSGLEN * 3 +1]; // text to send.  +1 for newline
    int          slen;       // length of text to output
    int          newenc0;
    int          newenc1;

    // get pointers to this instance of the plug-in and its slot
    pctx = (HBA_QUAD *) trans; // transparent data is our context

    // Read value in quadrature registers
    // Read four bytes offset by -1 (4 -1)
    pkt[0] = HBA_READ_CMD | ((4 -1) << 4) | pctx->coreid;
    pkt[1] = HBA_QUAD_REG_ENC1_LSB;
    pkt[2] = 0;                     // dummy byte (cmd)
    pkt[3] = 0;                     // dummy byte (reg)
    pkt[4] = 0;                     // dummy byte (q0 low)
    pkt[5] = 0;                     // dummy byte (q0 high)
    pkt[6] = 0;                     // dummy byte (q1 low)
    pkt[7] = 0;                     // dummy byte (q1 high)
    nsd = pctx->sendrecv_pkt(8, pkt);

    // We sent header + six bytes so the sendrecv return value should be 8
    if (nsd != 8) {
        // error reading value from QUAD port
        edlog("Error reading value from quadrature");
        return;
    }
    newenc0 = (pkt[3]<<8) | pkt[2];   // Reconstruct 16-bit value.
    newenc1 = (pkt[5]<<8) | pkt[4];   // Reconstruct 16-bit value.
 
    // Broadcast encoder 0 if it's changed and any UI is monitoring it
    pslot = pctx->pslot;
    if (newenc0 != pctx->enc0) {
        prsc = &(pslot->rsc[RSC_ENC0]);
        if (prsc->bkey != 0) {
            slen = snprintf(msg, (MX_MSGLEN -1), "%04x\n", newenc0);
            bcst_ui(msg, slen, &(prsc->bkey));
        }
    }
    // Broadcast encoder 1 if it's changed and any UI is monitoring it
    if (newenc1 != pctx->enc1) {
        prsc = &(pslot->rsc[RSC_ENC1]);
        if (prsc->bkey != 0) {
            slen = snprintf(msg, (MX_MSGLEN -1), "%04x\n", newenc1);
            bcst_ui(msg, slen, &(prsc->bkey));
        }
    }
    pctx->enc0 = newenc0;
    pctx->enc1 = newenc1;
}


// end of hba_enc.c

