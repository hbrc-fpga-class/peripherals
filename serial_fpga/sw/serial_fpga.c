/*
 *  Name: serial_fpga.c
 *
 *  Description: Simple interface to a Linux serial port
 *
 *  Resources:
 *    port   -  full path to serial port (/dev/serial0)
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
#include <sys/ioctl.h> 
#include <linux/serial.h>
#include "eedd.h"
#include "hba.h"
#include "readme.h"



/**************************************************************
 *  - Limits and defines
 **************************************************************/
        // hardware register definitions
#define HBA_SF_REG_INTR0       (0)
#define HBA_SF_REG_INTR1       (1)
#define HBA_SF_REG_RATE        (2)
        // resource names and numbers
#define FN_PORT            "port"
#define FN_CONFIG          "config"
#define FN_INTRRP          "intrr_pin"
#define FN_RAWIN           "rawin"
#define FN_RAWOUT          "rawout"
#define FN_INTRRT          "intrr_rate"
#define RSC_PORT           0
#define RSC_CONFIG         1
#define RSC_INTRRP         2
#define RSC_RAWIN          3
#define RSC_RAWOUT         4
#define RSC_INTRRT         5
        // What we are is a ...
#define PLUGIN_NAME        "serial_fpga"
        // Default serial port
#define DEFDEV             "/dev/serial0"
        // Default baudrate
#define DEFBAUD            115200
        // Default interrupt GPIO pin
#define HBA_DEF_INTR      (25)



/**************************************************************
 *  - Data structures
 **************************************************************/
    // Per core information kept by this module
typedef struct
{
    void    (*intr_hndlr) ();    // interrupt handler
    void     *trans;             // data to pass transparently to handler 
} COREINFO;

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
    int      intrrp;   // interrupt input gpio
    int      irfd;     // interrupt pin file descriptor (-1 if closed)
    int      intrrt;   // interrupt rate in hz
    COREINFO coreinfo[NCORE];
} SERPORT;


/**************************************************************
 *  - Function prototypes and external references
 **************************************************************/
int sendrecv_pkt(int count, uint8_t *buff);
static void getevents(int, void *);
static void usercmd(int, int, char*, SLOT*, int, int*, char*);
static int  portconfig(SERPORT *pctx);
static int  gpioconfig(int pin);
static void do_interrupt(int fd, void *pctx);
void        register_interupt_handler(int, void (*)());
extern SLOT Slots[];
extern int  DebugMode;
extern int  ForegroundMode;


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
    pctx->pslot = pslot;       // this instance of serial_fpga
    pctx->baud = DEFBAUD;      // default baud rate
    pctx->inidx = 0;           // no bytes in input buffer
    pctx->outidx = 0;          // no bytes in output buffer
    pctx->spfd = -1;           // port is not yet open
    (void) strncpy(pctx->port, DEFDEV, PATH_MAX);
    // no default for the interrupt pin. 
    pctx->intrrp = HBA_DEF_INTR;  // interrupt gpio
    pctx->intrrt = 0;             // 0 rate indicates no delay.
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
    pslot->rsc[RSC_INTRRT].name = FN_INTRRT;
    pslot->rsc[RSC_INTRRT].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_INTRRT].bkey = 0;
    pslot->rsc[RSC_INTRRT].pgscb = usercmd;
    pslot->rsc[RSC_INTRRT].uilock = -1;
    pslot->rsc[RSC_INTRRT].slot = pslot;

    pctx->ptimer = (void *) 0;

    // try to open and register the serial port
    (void) portconfig(pctx);  // void since there is no ui

    // try to allocate the default interrupt gpio pin
    pctx->irfd = gpioconfig(pctx->intrrp);
    if (pctx->irfd >= 0) {       // config succeeded?
        // Add fd to exception list for select()
        add_fd(pctx->irfd, ED_EXCEPT, do_interrupt, (void *) pctx);
    }

    return (0);
}


/**************************************************************
 * usercmd():  - The user is reading or setting a resource
 **************************************************************/
static void usercmd(
    int      cmd,      //==EDGET if a read, ==EDSET on write
    int      rscid,    // ID of resource being accessed
    char    *val,      // new value for the resource
    SLOT    *pslot,    // pointer to slot info.
    int      cn,       // Index into UI table for requesting conn
    int     *plen,     // size of buf on input, #char in buf on output
    char    *buf)
{
    SERPORT *pctx;     // serial_fpga private info
    int      ret;      // generic call return value.  Reused.
    int      nbaud;    // new value to assign the baud
    char    *pbyte;    // used in parsing raw input
    int      tmp;      // used in parsing raw input
    int      intrpin;  // new interrupt GPIO pin
    int      intrrate; // new interrupt rate in hz
    int      intrrt_ms; // new interrupt rate in ms
    int      nsd;      // number of bytes sent to FPGA
    uint8_t  pkt[HBA_MXPKT];

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
    else if ((cmd == EDGET) && (rscid == RSC_INTRRP)) {
        ret = snprintf(buf, *plen, "%d\n", pctx->intrrp);
        *plen = ret;  // (errors are handled in calling routine)
    }
    else if ((cmd == EDGET) && (rscid == RSC_INTRRT)) {
        ret = snprintf(buf, *plen, "%d\n", pctx->intrrt);
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
        ret = portconfig(pctx);
        if (ret < 0) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
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

        // record the new baudrate and reconfigure serial port
        pctx->baud = nbaud;
        portconfig(pctx);
    }
    else if ((cmd == EDSET) && (rscid == RSC_INTRRP)) {
        ret = sscanf(val, "%d", &intrpin);
        if ((ret != 1) || (intrpin < 0) || (intrpin > 100)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        pctx->intrrp = intrpin;
        // close and unregister the old port
        if (pctx->irfd >= 0) {
            del_fd(pctx->irfd);
            close(pctx->irfd);
            pctx->irfd = -1;
        }
        pctx->irfd = gpioconfig(pctx->intrrp);
        if (pctx->irfd < 0) {       // config failed?
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // Add fd to exception list for select()
        add_fd(pctx->irfd, ED_EXCEPT, do_interrupt, (void *) pctx);
    }
    else if ((cmd == EDSET) && (rscid == RSC_INTRRT)) {
        ret = sscanf(val, "%d", &intrrate);
        if ((ret != 1) || (intrrate < 4) || (intrrate > 1000)) {
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }

        // Convert hz to ms
        if (intrrate < 4) {
            intrrt_ms = 0;
        } 
        else if (intrrate > 1000) {
            intrrt_ms = 255;
        }
        else {
            intrrt_ms = ((int)((1.0/intrrate)*1000)) & 0xff;
        }

        // record the new data value
        // XXX pctx->intrrt = intrrt_ms;    // in ms
        pctx->intrrt = intrrate;    // in hz

        // Send new value to the FPGA serial_fpga rate register(reg2)
        pkt[0] = HBA_WRITE_CMD | ((1 -1) << 4) | 0; // serial_fpga core 0.
        pkt[1] = HBA_SF_REG_RATE;
        pkt[2] = intrrt_ms;                     // new value
        pkt[3] = 0;                             // dummy for the ack

        nsd = sendrecv_pkt(4, pkt);
        // We did a write so the sendrecv return value should be 1
        // and the returned byte should be an ACK
        if ((nsd != 1) || (pkt[0] != HBA_ACK)) {
            // error writing value from SERIAL_FPGA port
            ret = snprintf(buf, *plen, E_NORSP, pslot->rsc[rscid].name);
            *plen = ret;
        }

        // close and unregister the old port
        if (pctx->irfd >= 0) {
            del_fd(pctx->irfd);
            close(pctx->irfd);
            pctx->irfd = -1;
        }
        pctx->irfd = gpioconfig(pctx->intrrp);
        if (pctx->irfd < 0) {       // config failed?
            ret = snprintf(buf, *plen, E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        // Add fd to exception list for select()
        add_fd(pctx->irfd, ED_EXCEPT, do_interrupt, (void *) pctx);
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
                if (ret < 0) {
                    close(pctx->spfd);
                    pctx->spfd = -1;
                }
                ret = snprintf(buf, *plen, E_NORSP, pctx->port);
                *plen = ret;
                return;
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
 * fd is -1.  Just config if fd is >= 0.  Sets pctx->spfd.
 * Return fd so errors can be handled in calling routine.
 */
static int portconfig(SERPORT *pctx)
{
    struct termios tbuf;        // termios structure for port
    speed_t baudrate;           // baudrate for cfsetospeed
    struct serial_struct serial; // for low latency

    if (pctx->spfd < 0) {
        pctx->spfd = open(pctx->port, (O_RDWR | O_NOCTTY | O_NONBLOCK), 0);
        if (pctx->spfd < 0) {
            return(pctx->spfd);
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
        return(pctx->spfd);
    }

    // Configure port for low latency
    ioctl(pctx->spfd, TIOCGSERIAL, &serial); 
    serial.flags |= ASYNC_LOW_LATENCY;
    ioctl(pctx->spfd, TIOCSSERIAL, &serial);

    // add callback for received characters
    add_fd(pctx->spfd, ED_READ, getevents, (void *) pctx);
    return(pctx->spfd);
}


/* Open and configure the gpio port for interrupts.   Return opened
 * file descriptor on success and -1 on failure.
 */
static int gpioconfig(int pin)
{
    int           gpfd;         // the fd of the opened GPIO pin
    int           sysfd;        // fd for /sys/class/gpio/....
    char          pinname[MX_MSGLEN]; // pin number as an ascii string
    int           pinlen;       // length of string in pinname
    int           ret;          // generic system return value


    // simple sanity check on pin value
    if ((pin < 0) || (pin > 1000)) {
       edlog("Invalid GPIO pin for interrupts");
       return(-1);
    }
    pinlen = snprintf(pinname, MX_MSGLEN, "%d", pin);

    // Open /sys/class/gpio/export and write the pin number to it
    sysfd =open("/sys/class/gpio/export", (O_RDWR), 0);
    if (sysfd < 0) {
        edlog("Unable to open /sys/class/gpio/export.  Are you root?");
        return(-1);
    }
    ret = write(sysfd, pinname, pinlen);
    if (ret != pinlen) {
        edlog("Warning: could not write pin name to /sys/class/gpio/export");
    }
    close(sysfd);
    usleep(100000);    // give the kernal a chance to set up gpio

    // Open edge for the GPIO pin and configure the port to be
    // read ready on a rising edge
    pinlen = snprintf(pinname, MX_MSGLEN, "/sys/class/gpio/gpio%d/edge", pin);
    sysfd = open(pinname, (O_RDWR), 0);
    if (sysfd < 0) {
        edlog("Unable to open %s", pinname);
        close(sysfd);
        return(-1);
    }
    ret = write(sysfd, "rising", 6);      // 6=strlen("rising")
    if (ret != 6) {
        edlog("Unable to configure %s", pinname);
        close(sysfd);
        return(-1);
    }
    close(sysfd);

    // Open value for the GPIO pin.  This is what we read in select()
    pinlen = snprintf(pinname, MX_MSGLEN, "/sys/class/gpio/gpio%d/value", pin);
    gpfd =open(pinname, (O_RDONLY), 0);
    if (gpfd < 0) {
        edlog("Unable to open %s", pinname);
        return(-1);
    }
 
    return(gpfd);
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
    int           i;

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

    // Print pkt if debug mode and running in foreground
    if ((DebugMode != 0) && (ForegroundMode != 0)) {
        printf(">> ");
        for (i = 0; i < count; i++)
            printf("%02x ", buff[i]);
        printf("\n");
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
        select_tv.tv_usec = (useconds_t) 1000000;   // 0.1 seconds for a timeout
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
                    // Print pkt if debug mode and running in foreground
                    if ((DebugMode != 0) && (ForegroundMode != 0)) {
                        printf("<< ");
                        for (i = 0; i < expectrd; i++)
                            printf("%02x ", buff[i]);
                        printf("\n");
                    }
                    return(expectrd);
                }
                // else more to read, drop back into select() to wait
            }
        }
    }
}


/* register_interrupt_handler() : Plug-in modules use this routine
 * to tell serial_fpga the address of the module's interrupt handler.
 * The plug-in passes in both the slot number (which equals the core
 * ID) as well as the address of the handler.  
 */
void register_interrupt_handler(
    int           coreid,       // core ID (same as plugin slot #)
    void        (*handler)(),   // address of interrupt handler
    void         *trans)        // transparently pass this to handler
{
    SERPORT      *pctx;         // our local info

    // We could search the slots for a plug-in named "serial_fpga" but
    // for now we assume that serial_fpga is the first module loaded.
    pctx = (SERPORT *) Slots[0].priv;
    if (strncmp(PLUGIN_NAME, Slots[0].name, strlen(PLUGIN_NAME)) != 0) {
        edlog("Wanted %s in Slot 0.  Exiting...\n", PLUGIN_NAME);
        exit(1);
    }

    // Sanity check the coreid and handler address
    if ((coreid < 0) || (coreid >= NCORE) || (handler == 0)) {
        edlog("Bad calling values to register_interrupt_handler()");
        return;
    }

    pctx->coreinfo[coreid].intr_hndlr = handler;
    pctx->coreinfo[coreid].trans      = trans;
}


/***************************************************************************
 * do_interrupt(): - Hnadle an interrupt request.  Read the interrupt
 * pending registers in serial_fpga peripheral and invoke the appropriate
 * interrupt handlers if one is registered.  Log interrupts that do not
 * have a handler.
 ***************************************************************************/
static void do_interrupt(
    int       fd_in,         // FD with data to read,
    void     *cb_data)       // callback date (==*SERPORT)
{
    SERPORT  *pctx;          // our context
    int       nrc;           // number of bytes recieved
    int       intpending;    // a set bit means and interrupt is pending
    int       ret;           // generic return value from a system call
    int       i;             // to walk the cores
    uint8_t   pkt[HBA_MXPKT];  


    pctx = (SERPORT *) cb_data;

    // We need to read the GPIO value to clear the interrupt
    (void) lseek(pctx->irfd, (off_t) 0, SEEK_SET);
    ret = read(pctx->irfd, pkt, HBA_MXPKT);
    if (ret <= 0) {
        edlog("Error reading interrupt GPIO pin");
        return;
    }

    // Noise on the interrupt line can trigger a rising edge.
    // Verify that the interrupt pin really is high
    if (pkt[0] != '1') {
        return;
    }

    // Read the two interrupt registers in serial_fpga
    //  (2-1) is # byte to read -1, and 0 is our coreID
    pkt[0] = HBA_READ_CMD | ((2 -1) << 4) | 0;
    pkt[1] = HBA_SF_REG_INTR0;
    pkt[2] = 0;                     // dummy byte
    pkt[3] = 0;                     // dummy byte
    pkt[4] = 0;                     // dummy byte
    pkt[5] = 0;                     // dummy byte
    nrc = sendrecv_pkt(6, pkt);
    // We sent header + two bytes so the sendrecv return value should be 4
    if (nrc != 4) {
        // error reading value from GPIO port
        edlog("Error reading interrupt pending register from FPGA");
        return;
    }
    intpending = pkt[2] | (pkt[3] << 8);

    // Sanity check
    if (intpending == 0) {
        edlog("Interrupt but no bits set in pending registers");
        return;
    }

    // walk the pending interrupts invoking the handlers.  No need to check
    // at zero since that's us.
    for (i = 1;  i < NCORE; i++) {
        intpending = intpending >> 1;
        if ((intpending & 0x01) == 1) {
            // interrupt is pending on this core.  Invoke its handler
            if (pctx->coreinfo[i].intr_hndlr == 0) {
                edlog("Received unhandled interrupt in core %d", i);
                continue;
            }
            // invoke handler
            (pctx->coreinfo[i].intr_hndlr) (pctx->coreinfo[i].trans);
        }
    }
}

// end of serial_fpga.c
