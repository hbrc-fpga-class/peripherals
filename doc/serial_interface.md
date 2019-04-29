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
* __rts (output)__ : Request to Send. RPI asserts to signal transaction. Active low.
Holds low until transaction is complete.
* __intr (input)__ : Interrupt from FPGA. Indicates that the FPGA has data to be read.
* __cts (input)__ : Clear to Send. Indicates that the FPGA is ready for a byte.  Active low.
The RPI must check this signal is low before sending a new byte.

## Protocol

The Raspberry Pi is the master on the bus and controls reading
and writing to the FPGA registers.  The address is split into two
parts, core address and register address.  The core address is 4-bits
So there can be a total of 16 cores.  The register address is 8-bits,
so each core can have up to 256 registers.  The basic protocol looks like
this:
* __RPI pulls rts low__ : This signals to the FPGA that the RPI is going 
to start a transaction.
* __Command[3:0]__ : This is the command nibble.
    * __0__ : Read=1, Write=0.
    * __3:1__ : The number of bytes to read or write minus 1.  So 1 to 8 bytes
    can be transfered in one transaction.  The register address is auto incremented
    after each data byte.
* __CoreAddress[3:0]__ : The Core Address.  Selects desired core.
* __RegAddress[7:0]__ : The Register Address.  Selects register index of selected
* __Read Header (READ ONLY)__ : The First two bytes (Command[3:0], CoreAddress[3:0], RegAddress[7:0])  are echoed back for read operations.  The bytes are echoed back on __rxd__.  Simultaneously the RPI send two dummy bytes on __txd__.  This allows the RPI to control the data rate sent from the FPGA.
* __Data0..N-1[7:0]__ : The N bytes of data to read or write.  Data direction
is specified the Command[0] and N is specified by Command[3:1].  For a __read__
the data is returned starting from the lowest reg address first.  The bytes are sent back on __rxd__.  Simultaneously the RPI send a dummy byte on __txd__ for each byte read.  This allows the RPI to control the data rate sent from the FPGA. For __write__ the lowest
reg address is written first.  The FPGA will auto-increment the reg address after each byte.
* __ACK/NACK (WRITE ONLY)__ : For a write operation. The FPGA sends an ACK to confirm the writes occured or a NACK
if there was an error.  The value for ACK is 0xAC, the value for NACK is 0x56.  For read operations no ACK/NACK is returned.
* __RPI releases rts__ : This signals to the FPGA that the transaction has
  completed.


