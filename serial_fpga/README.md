# serial_fpga

## Description

This module implements communication between a host
processor, over RS232, to the HBA (HomeBrew Automation)
peripherals on the FPGA.

Usually this peripheral is installed in slot0.

## Interface

This module is both a HBA Master and an HBA Slave.
Additional ports are:
* __io_rxd__ : Receive data pin.
* __io_txd__ : Transmit data pin.
* __io_intr__ : Asserted when a slave interrupt occurs.  Clears when
the interrupt registers (below) are read.
* __slave_interrupt[15:0]__ : Interrupts from up to 16 slave peripherals.

The slave interface exposes two registers.  These registers are auto-cleared
after they have been read by the host (or other master).

* __reg0[7:0]__ : (reg_intr0) Interrupt flags for peripherals 7 .. 0.
* __reg1[7:0]__ : (reg_intr1) Interrupt flags for peripherals 15 .. 8.
* __reg2[7:0]__ : (reg_baud_code) Code for the specified baud rate. Values:
    * CODE  | Baud rate
    * 0     | 9600
    * 1     | 19200
    * 2     | 38400
    * 3     | 57600
    * 4     | 115200 (Default)
    * 5     | 230400
    * 6     | 460800
    * 7     | 921600

## ToDo

* Add support to change baud rate through the slave register interface.
* Rename this peripheral hba_serial_fpga.

