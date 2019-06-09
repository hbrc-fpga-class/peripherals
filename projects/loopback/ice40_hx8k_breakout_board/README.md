# loopback ice40hx8k Breakout board

## Description

This project is a test of the uart.
It reads a character from the rx side
of the uart then sends it on the tx side.
It also displayed the echoed character on the leds.

The Makefile for the ice40hx8k breakout board
is a little different from the TinyFPGA board.
The former uses the **iceprog** to program the 
FPGA/flash. While the later  uses **tinyprog**.

On my computer when I plug in the ice40hx8k breakout
board I see two serial ports:
* /dev/ttyUSB0 : Used by iceprog to program the flash or FPGA
  sram (depends on jumper settings).
* /dev/ttyUSB1 : The serial port

## Example

In Terminal 1:
* Start the hbadaemon
* Load the serial_fpga.so
* Set the baud rate
* Set the serial port
* Write a hex number on port and see the value on the leds.

```
hbadaemon -ef &
hbaloadso serial_fpga.so
hbaset serial_fpga config 115200
hbaset serial_fpga port /dev/ttyUSB1
hbaset serial_fpga rawout 55
```

In Terminal 2:
* Show the echoed characters

```
hbacat serial_fpga rawin
```

Now go back to Terminal 1 and send bytes to rawout.  You should
see the values echoed on the LED and in Terminal 2.

```
hbaset serial_fpga rawout AA
hbaset serial_fpga rawout 55
hbaset serial_fpga rawout AA
...
```

To quit the hbadaemon go to Terminal 1 and type

```
fg
ctrl-c
```



