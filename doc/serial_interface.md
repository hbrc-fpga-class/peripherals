# Serial Interface

## Description

This document describes the serial interface
between the raspberry PI and the FPGA board.

## Serial Interface

The following table describes the signals between
the RPI and the FPGA board. Inputs and output are from
the perspective of the raspberry pi (RPI).
* __txd (output)__ : Transmit data to the FPGA.
* __rxd (input)__  : Receive data from the FPGA
* __intr (input)__ : Interrupt from FPGA. Indicates that the FPGA has data to be read.

NOTE: Removed the RTS/CTS handshaking. More information about the RTS/CTS handshaking:
* [Section 3.1 : Hardware Flow Control](https://www.silabs.com/documents/public/application-notes/an0059.0-uart-flow-control.pdf)
* [Raspberry Pi Hardware Flow Control](https://github.com/mholling/rpirtscts)

## Protocol

The Raspberry Pi is the master on the bus and controls reading
and writing to the FPGA registers.  The address is split into two
parts, core address and register address.  The core address is 4-bits
So there can be a total of 16 cores.  The register address is 8-bits,
so each core can have up to 256 registers.  The basic protocol looks like
this:
* __Command[7:0]__ : This is the command nibble.
    * __7__ : Read=1, Write=0.
    * __6:4__ : The number of bytes to read or write minus 1.  So 1 to 8 bytes
    can be transfered in one transaction.  The register address is auto incremented
    after each data byte.
    * __3:0__ : The Core Address.  Selects desired core.
* __RegAddress[7:0]__ : The Register Address.  Selects register index of selected
* __Read Header (READ ONLY)__ : The First two bytes (Command[3:0], CoreAddress[3:0], RegAddress[7:0])  are echoed back for read operations.  The bytes are echoed back on __rxd__.  Simultaneously the RPI send two dummy bytes on __txd__.  This allows the RPI to control the data rate sent from the FPGA.
* __Data0..N-1[7:0]__ : The N bytes of data to read or write.  Data direction
is specified the Command[0] and N is specified by Command[3:1].  For a __read__
the data is returned starting from the lowest reg address first.  The bytes are sent back on __rxd__.  Simultaneously the RPI send a dummy byte on __txd__ for each byte read.  This allows the RPI to control the data rate sent from the FPGA. For __write__ the lowest
reg address is written first.  The FPGA will auto-increment the reg address after each byte.
* __ACK/NACK (WRITE ONLY)__ : For a write operation. The FPGA sends an ACK to confirm the writes occured or a NACK
if there was an error.  The value for ACK is 0xAC, the value for NACK is 0x56.  For read operations no ACK/NACK is returned.

## Example

### Write Transaction

This show the bytes sent to write to peripheral 0.  It writes
the values 0x10, 0x11, 0x12, 0x13 to the first 4 regsiters.
The ack value of 0xAC is returned:

```
// cmd:         0011_0000   - (0x30) write (3+1) at core addr 0
// reg_addr:    0000_0000   - (0x00) start at address 0
// data0:       0001_0000   - (0x10) 16
// data1:       0001_0001   - (0x11) 17
// data2:       0001_0010   - (0x12) 18
// data3:       0001_0011   - (0x13) 19
// dummy:       FFFF_FFFF   - (0xFF) dummy byte to read back ack

sent:  30 00 10 11 12 13 FF
reply:                   AC
```

## Read Transaction

This shows the bytes sent to read the first 4 registers of peripheral 0.
The two command byte are echoed back, plus the 4 register values.
Note: the RPI sends dummy bytes (in this case 0xFF) to trigger the FPGA to send
back a value.

```
// cmd:         1011_0000   - (0xB0) read (3+1) at core addr 0
// reg_addr:    0000_0000   - (0x00) start at address 0
// dummy:       FFFF_FFFF   - (0xFF) dummy byte to read back cmd
// dummy:       FFFF_FFFF   - (0xFF) dummy byte to read back regaddr
// dummy0:      FFFF_FFFF   - (0xFF) dummy byte to read back reg0
// dummy1:      FFFF_FFFF   - (0xFF) dummy byte to read back reg1
// dummy2:      FFFF_FFFF   - (0xFF) dummy byte to read back reg2
// dummy3:      FFFF_FFFF   - (0xFF) dummy byte to read back reg3

sent:  B0 00 FF FF FF FF FF FF
reply:       B0 00 10 11 12 13
```

## Notes
* The Handshaking signals __rts__ and __cts__ are probably not necessary.
* Perhaps we can do away with sending the number of bytes to read or write.  We could have a __done__ signal which is asserted to indicate the end of a read or write packet.


