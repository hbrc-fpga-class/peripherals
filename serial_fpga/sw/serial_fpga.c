/*
 *  Name: serial_fpga.c
 *
 *  Description: Simple interface to a Linux serial port
 *
 *  Resources:
 *    port   -  full path to serial port (/dev/input/ttyUSB0)
 *    config -  baudrate in range of 1200 to 921000
 *    intrr_pin -  which pin to monitor as an interrupt
 *    rawin  -  Received characters displayed in hex
 *    rawout -  Characters to send to serial port
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
#include <unistd.h>
#include "eedd.h"
#include "readme.h"
#define HBAERROR_NOSEND (-1)
#define HBAERROR_NORECV (-2)
#define HBA_READ_CMD    (0x80)
#define HBA_WRITE_CMD           (0x00)
#define HBA_MXPKT               (16)
#define HBA_SFPGA_REG_INTR0     (0)
#define HBA_SFPGA_REG_INTR1     (1)
#define HBA_SFPGA_REG_BAUDC     (2)
#define HBA_ACK                 (0xAC)


/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // resource names and numbers
#define FN_PORT            "port"
#define FN_CONFIG          "config"
#define FN_INTRRP          "intrr_pin"
#define FN_RAWIN           "rawin"
#define FN_RAWOUT          "rawout"
#define RSC_PORT           0
#define RSC_CONFIG         1
#define RSC_INTRRP         2
#define RSC_RAWIN          3
#define RSC_RAWOUT         4
        // What we are is a ...
#define PLUGIN_NAME        "serial_fpga"
        // Default serial port
#define DEFDEV             "/dev/ttyUSB1"
        // Default baudrate
#define DEFBAUD             115200
// XXX #define DEFBAUD             921600
        // Maximum size of input/output string
#define MX_MSGLEN          120


/**************************************************************
 *  - Data structures
 **************************************************************/
    // All state info for an instance of an hba_serial_fpga peripheral
typedef struct
{
    void    *pslot;    // handle to plug-in's's slot info
    int      baud;     // baudrate
    void    *ptimer;   // timer with callback to bcast state
    char     port[PATH_MAX]; // full path to serial port node
    int      spfd;     // serial port File Descriptor (=-1 if closed)
    uint8_t  rawinc[MX_MSGLEN];  // data from fpga to host
    int      inidx;    // index into rawinc
    uint8_t  rawoutc[MX_MSGLEN];  // data from host to fpga
    int      outidx;   // index into rawoutc
    char     intrrp[PATH_MAX]; // full path to interrupt input pin
    int      irfd;     // interrupt pin file descriptor (-1 if closed)
} SERPORT;


/**************************************************************
 *  - Function prototypes
 **************************************************************/
static void getevents(int, void *);
static void usercmd(int, int, char*, SLOT*, int, int*, char*);
static void portconfig(SERPORT *pctx);
extern SLOT Slots[];

int sendrecv_pkt(int, uint8_t*);

/**************************************************************
 * Initialize():  - Allocate our permanent storage and set up
 * the read/write callbacks.
 **************************************************************/
int Initialize(
    SLOT *pslot)       // points to the SLOT for this plug-in
{
    SERPORT *pctx;     // our local port context

    // Allocate memory for this plug-in
    pctx = (SERPORT *) malloc(sizeof(SERPORT));
    if (pctx == (SERPORT *) 0) {
        // Malloc failure this early?
        edlog("memory allocation failure in serial_fpga initialization");
        return (-1);
    }

    // Init our SERPORT structure
    pctx->pslot = pslot;       // this instance of the hello demo
    pctx->baud = DEFBAUD;      // default baud rate
    pctx->inidx = 0;           // no bytes in input buffer
    pctx->outidx = 0;          // no bytes in output buffer
    pctx->spfd = -1;           // port is not yet open
    (void) strncpy(pctx->port, DEFDEV, PATH_MAX);
    // no default for the interrupt pin. 
    pctx->intrrp[0] = (char) 0;  // full path to interrupt input pin
    pctx->irfd = -1;           // interrupt pin file descriptor (-1 if closed)

    // Register name and private data
    pslot->name = PLUGIN_NAME;
    pslot->priv = pctx;
    pslot->desc = "Serial interface to the HomeBrew Automation FPGA";
    pslot->help = README;

    // Add handlers for the user visible resources
    pslot->rsc[RSC_PORT].slot = pslot;
    pslot->rsc[RSC_PORT].name = FN_PORT;
    pslot->rsc[RSC_PORT].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_PORT].bkey = 0;
    pslot->rsc[RSC_PORT].pgscb = usercmd;
    pslot->rsc[RSC_PORT].uilock = -1;
    pslot->rsc[RSC_CONFIG].name = FN_CONFIG;
    pslot->rsc[RSC_CONFIG].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_CONFIG].bkey = 0;
    pslot->rsc[RSC_CONFIG].pgscb = usercmd;
    pslot->rsc[RSC_CONFIG].uilock = -1;
    pslot->rsc[RSC_CONFIG].slot = pslot;
    pslot->rsc[RSC_INTRRP].name = FN_INTRRP;
    pslot->rsc[RSC_INTRRP].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_INTRRP].bkey = 0;
    pslot->rsc[RSC_INTRRP].pgscb = usercmd;
    pslot->rsc[RSC_INTRRP].uilock = -1;
    pslot->rsc[RSC_INTRRP].slot = pslot;
    pslot->rsc[RSC_RAWOUT].name = FN_RAWOUT;
    pslot->rsc[RSC_RAWOUT].flags = IS_WRITABLE;
    pslot->rsc[RSC_RAWOUT].bkey = 0;
    pslot->rsc[RSC_RAWOUT].pgscb = usercmd;
    pslot->rsc[RSC_RAWOUT].uilock = -1;
    pslot->rsc[RSC_RAWOUT].slot = pslot;
    pslot->rsc[RSC_RAWIN].name = FN_RAWIN;
    pslot->rsc[RSC_RAWIN].flags = CAN_BROADCAST;
    pslot->rsc[RSC_RAWIN].bkey = 0;
    pslot->rsc[RSC_RAWIN].pgscb = 0;
    pslot->rsc[RSC_RAWIN].uilock = -1;
    pslot->rsc[RSC_RAWIN].slot = pslot;

    pctx->ptimer = (void *) 0;

    // try to open and register the serial port
    portconfig(pctx);

    return (0);
}


/**************************************************************
 * usercmd():  - The user is reading or setting a resource
 **************************************************************/
void usercmd(
    int      cmd,      //==EDGET if a read, ==EDSET on write
    int      rscid,    // ID of resource being accessed
    char    *val,      // new value for the resource
    SLOT    *pslot,    // pointer to slot info.
    int      cn,       // Index into UI table for requesting conn
    int     *plen,     // size of buf on input, #char in buf on output
    char    *buf)
{
    SERPORT *pctx;     // serial_fpga private info
    int      ret;      // generic system call return value
    int      nbaud;    // new value to assign the baud
    char    *pbyte;    // used in parsing raw input
    int      tmp;      // used in parsing raw input
    uint8_t  pkt[HBA_MXPKT];
    uint8_t  baud_code; // FPGA code for specified baud_rate
    int      nsd;      // number of bytes sent to FPGA

    // Get this instance of the plug-in
    pctx = (SERPORT *) pslot->priv;


    if ((cmd == EDGET) && (rscid == RSC_PORT)) {
        ret = snprintf(buf, *plen, "%s\n", pctx->port);
        *plen = ret;  // (errors are handled in calling routine)
    }
    else if ((cmd == EDGET) && (rscid == RSC_CONFIG)) {
        ret = snprintf(buf, *plen, "%d\n", pctx->baud);
        *plen = ret;  // (errors are handled in calling routine)
    }
    if ((cmd == EDGET) && (rscid == RSC_INTRRP)) {
        ret = snprintf(buf, *plen, "%s\n", pctx->intrrp);
        *plen = ret;  // (errors are handled in calling routine)
    }
    else if ((cmd == EDSET) && (rscid == RSC_PORT)) {
        // Val has the new port path.  Just copy it.
        (void) strncpy(pctx->port, val, PATH_MAX);
        // strncpy() does not force a null.  We add one now as a precaution
        pctx->port[PATH_MAX -1] = (char) 0;
        // close and unregister the old port
        if (pctx->spfd >= 0) {
            del_fd(pctx->spfd);
            close(pctx->spfd);
            pctx->spfd = -1;
        }
        // now open and register the new port
        portconfig(pctx);
    }
    else if ((cmd == EDSET) && (rscid == RSC_CONFIG)) {
        ret = sscanf(val, "%d", &nbaud);
        if (ret != 1) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        if ((nbaud != 1200) && (nbaud != 1800) && (nbaud != 2400) &&
            (nbaud != 4800) && (nbaud != 9600) && (nbaud != 19200) &&
            (nbaud != 38400) && (nbaud != 57600) && (nbaud != 115200) &&
            (nbaud != 230400) && (nbaud != 460800) && (nbaud != 500000) &&
            (nbaud != 576000) && (nbaud != 921600))
        {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }

        // Set the FPGA baud_code
        switch (nbaud) {
            case 1200   : baud_code = 0; break;
            case 1800   : baud_code = 1; break;
            case 2400   : baud_code = 2; break;
            case 4800   : baud_code = 3; break;
            case 9600   : baud_code = 4; break;
            case 19200  : baud_code = 5; break;
            case 38400  : baud_code = 6; break;
            case 57600  : baud_code = 7; break;
            case 115200 : baud_code = 8; break;
            case 230400 : baud_code = 9; break;
            case 460800 : baud_code = 10; break;
            case 500000 : baud_code = 11; break;
            case 576000 : baud_code = 12; break;
            case 921600 : baud_code = 13; break;
            default :
                ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
                *plen = ret;
                return;
        }

        // record the new baudrate and reconfigure serial port
        pctx->baud = nbaud;

        // Update FPGA baud rate
        // TODO
        printf("Attempt to change baud rate to: %d\n",nbaud);
        printf("baud_code: %d\n",baud_code);
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4); // assume periph 0.
        pkt[1] = HBA_SFPGA_REG_BAUDC;
        pkt[2] = baud_code;                     // new value
        pkt[3] = 0;                             // dummy for the ack
        nsd = sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from serial_fpga port
            edlog("Error writing serial_fpga leds to FPGA");
        }


        // Wait .30 seconds for FPGA baud rates to take affect
        // then update linux port baud rate
        sleep(2);
        portconfig(pctx);
    }
    else if ((cmd == EDSET) && (rscid == RSC_INTRRP)) {
        // Val has the new port path.  Just copy it.
        (void) strncpy(pctx->intrrp, val, PATH_MAX);
        // strncpy() does not force a null.  We add one now as a precaution
        pctx->intrrp[PATH_MAX -1] = (char) 0;
        // close and unregister the old port
        if (pctx->irfd >= 0) {
            del_fd(pctx->irfd);
            close(pctx->irfd);
            pctx->irfd = -1;
        }



        // now open and register the new interrupt pin




    }
    else if ((cmd == EDSET) && (rscid == RSC_RAWOUT)) {
        // User has given us a line of space separated 8-bit hex values.
        // Convert the values to binary 
        pctx->outidx = 0;
        pbyte = strtok(val, " ");
        while (pbyte) {
            sscanf(pbyte, "%x", &tmp);
            pctx->rawoutc[pctx->outidx] = (uint8_t) (tmp & 0x00ff);
            pbyte = strtok((char *) 0, " ");    // space separated
            pctx->outidx++;
            if (pctx->outidx == MX_MSGLEN)      // full buffer ?
                break;
        }
        // Send data to serial port
        if (pctx->spfd >= 0) {
            ret = write(pctx->spfd, pctx->rawoutc, pctx->outidx);
            if (ret != pctx->outidx) {
                // Error writing to serial port.  Ignore partial writes
                // and close fd on errors.  An overloaded serial link might
                // fail here first.
                edlog("Error writing to serial_fpga serial port\n");
                if (ret < 0) {
                    close(pctx->spfd);
                    pctx->spfd = -1;
                }
            }
        }
    }
    // Nothing to do here if edcat.  That is handled in the UI code

    return;
}


/***************************************************************************
 * getevents(): - Read event on the serial port
 ***************************************************************************/
static void getevents(
    int       fd_in,         // FD with data to read,
    void     *cb_data)       // callback date (==*SERPORT)
{
    SERPORT  *pctx;          // our context
    SLOT     *pslot;         // This instance of the serial plug-in
    RSC      *prsc;          // pointer to this slot's counts resource
    int       nrd;           // number of bytes read
    char      msg[MX_MSGLEN * 3 +1]; // text to send.  +1 for newline
    int       slen;          // length of text to output
    int       i;             // to walk the input buffer


    pctx = (SERPORT *) cb_data;
    pslot = pctx->pslot;

    // Read from the serial port and output the data if anyone is
    // watching the rawin resource.  See if an interrupt is registered
    // for the (implied) slot in the packet.  If there's a handler then
    // forward the packet to the slot's interrupt handler.

    nrd = read(pctx->spfd, pctx->rawinc, MX_MSGLEN);

    // shutdown manager conn on error or on zero bytes read */
    if ((nrd <= 0) && (errno != EAGAIN)) {
        close(pctx->spfd);
        del_fd(pctx->spfd);
        pctx->spfd = -1;
        return;
    }

    // Broadcast characters if any UI are monitoring it.
    // '3' because each input byte prints as 'xx '.
    prsc = &(pslot->rsc[RSC_RAWIN]);  // events resource
    if (prsc->bkey != 0) {
        for(i = 0 ; i < nrd ; i++) {
            sprintf(&msg[i * 3],"%02x ", pctx->rawinc[i]);
        }
        sprintf(&msg[i * 3], "\n");
        slen = (i * 3) + 1;
        bcst_ui(msg, slen, &(prsc->bkey));
        prompt(prsc->uilock);
    }
    return;
}


/* Open and/or configure the serial port.  Open and config if
 * fd is -1.  Just config if fd is >= 0.
 */
void portconfig(SERPORT *pctx)
{
    struct termios tbuf;        // termios structure for port
    speed_t baudrate;           // baudrate for cfsetospeed

    if (pctx->spfd < 0) {
        pctx->spfd = open(pctx->port, (O_RDWR | O_NONBLOCK), 0);
        if (pctx->spfd < 0) {
            return;             // fail quietly
        }
    }

    // Get baudrate
    switch(pctx->baud) {
        case 1200 : baudrate = B1200; break;
        case 1800 : baudrate = B1800; break;
        case 2400 : baudrate = B2400; break;
        case 4800 : baudrate = B4800; break;
        case 9600 : baudrate = B9600; break;
        case 19200 : baudrate = B19200; break;
        case 38400 : baudrate = B38400; break;
        case 57600 : baudrate = B57600; break;
        case 115200 : baudrate = B115200; break;
        case 230400 : baudrate = B230400; break;
        case 460800 : baudrate = B460800; break;
        case 500000 : baudrate = B500000; break;
        case 576000 : baudrate = B576000; break;
        case 921600 : baudrate = B921600; break;
    }

    // Port is open and spfd is valid.  Configure the port.
    tbuf.c_cflag = CS8 | CREAD | baudrate | CLOCAL;
    tbuf.c_iflag = IGNBRK;
    tbuf.c_oflag = 0;
    tbuf.c_lflag = 0;
    tbuf.c_cc[VMIN] = 1;        /* character-by-character input */
    tbuf.c_cc[VTIME] = 0;       /* no delay waiting for characters */
    int actions = TCSANOW;
    if (tcsetattr(pctx->spfd, actions, &tbuf) < 0) {
        edlog(M_BADPORT, pctx->spfd, strerror(errno));
        close(pctx->spfd);
        pctx->spfd = -1;
        return;
    }

    // add callback for received characters
    add_fd(pctx->spfd, getevents, (void (*)()) NULL, (void *) pctx);
}


/* sendrecv_pkt() : Send a packet to the FPGA.  Wait for the
 * response.  Write packet receive one byte in response and read
 * packets receive two less than the number of bytes sent.
 *     Input is the number of bytes to send and a pointer to a buffer
 * with the bytes to send.  The buffer does not need to be null terminated.
 *     On return the buffer is filled with the response bytes.
 * The return value is the number of bytes sent on success and a negative
 * error code on error.  Errors include:
 *  HBAERROR_NOSEND : unable to send the data
 *  HBAERROR_NORECV : unable to read the response
 *     This routine is typically called from a driver plug-in to send
 * a read or write command to the FPGA.  It may be called from within
 * serial_fpga itself for initialization and to help process interrupts.
 */
int sendrecv_pkt(
    int            count,       // num bytes to send / receive
    uint8_t       *buff)        // pointer to first char to send
{
    SERPORT      *pctx;         // our local info
    int           sntcount1;    // return from first call to write()
    int           sntcount2;    // return from second call to write()
    int           expectrd;     // number of bytes expected in FPGA response
    int           rdcount;      // return from read()
    int           rdsofar = 0;  // number of characters we've read so far
    fd_set        rdfs;         // read FDs for select()
    struct timeval select_tv;   // timeout for select()
    int           sret;         // select() return value

    // We could search the slots for a plug-in named "serial_fpga" but
    // for now we assume that serial_fpga is the first module loaded.
    pctx = (SERPORT *) Slots[0].priv;
    if (strncmp(PLUGIN_NAME, Slots[0].name, strlen(PLUGIN_NAME)) != 0) {
        edlog("Wanted %s in Slot 0.  Exiting...\n", PLUGIN_NAME);
        exit(1);
    }

    // Sanity check. Valid count.  Non-null buffer.  Port open.
    if ((count <= 0) || (buff == (uint8_t *) 0) || (pctx->spfd < 0)) {
        return(HBAERROR_NOSEND);
    }

    // send data out the serial port 
    sntcount1 = write(pctx->spfd, buff, count);
    if (sntcount1 != count) {
        if ((sntcount1 < 0) && (errno != EAGAIN) && (errno != EINTR)) {
            edlog("error writing to serial port in serial_fpga");
            return(HBAERROR_NOSEND);
        }

        // Partial send or need to try again.  Pause then try again.
        usleep(1000);
        // sntcount1 is offset into xmit buffer.  No negative sntcount1
        sntcount1 = (sntcount1 < 0) ? 0 : sntcount1;
        sntcount2 = write(pctx->spfd, &buff[sntcount1], (count - sntcount1));
        if (sntcount2 != (count - sntcount1)) {
            // no retry on second failure
            edlog("error writing to serial port in serial_fpga");
            return(HBAERROR_NOSEND);
        }
    }

    // Read characters from the serial port.  Use a select() loop
    // so we can detect a timeout error.
    // Expect response to have one byte for a write and two less than the
    // write count for a read.
    expectrd = (HBA_READ_CMD & buff[0]) ? (count -2) : 1 ;

    // We loop as long as we are reading bytes within the timeout period.
    // Bytes might dripple in especially on a slow link
    while (1) {
        select_tv.tv_sec = 0;
        select_tv.tv_usec = (useconds_t) 100000;   // 0.1 seconds for a timeout
        FD_ZERO(&rdfs);
        FD_SET(pctx->spfd, &rdfs);
        sret = select((pctx->spfd + 1), &rdfs, (fd_set *) 0, (fd_set *) 0, &select_tv);
        if (sret < 0) {
            // select error -- bail out on all but EINTR
            if (errno != EINTR) {
                edlog("Failure in select() call");
                exit(-1);
            }
        }
        else if (sret == 0) {
            // timeout waiting for the response
            edlog("timeout reading from serial port in serial_fpga");
            return(HBAERROR_NORECV);
        }
        else if ((pctx->spfd >= 0) && FD_ISSET(pctx->spfd, &rdfs)) {
            // read bytes from serial port
            rdcount = read(pctx->spfd, &(buff[rdsofar]), (expectrd - rdsofar));
            if ((rdcount < 0) && (errno != EINTR)) {
                edlog("error writing to serial port in serial_fpga");
                return(HBAERROR_NORECV);
            }
            if (rdcount > 0) {
                rdsofar += rdcount;
                if (rdsofar == expectrd) {   // done?
                    return(expectrd);
                }
                // else more to read, drop back into select() to wait
            }
        }
    }
}
// end of serial_fpga.c
