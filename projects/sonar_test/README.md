# sonar_test

## Description

This project implements the serial_fpga master in slot0.
The serial_fpga also implements a slave interface
in which you can read back the interrupt register
to see if any slaves asserted an interrupt.

It implements hba_sonar peripheral in slot1.
This peripheral controls up to two SR04 sonars.

See the serial_fpga and hba_sonar readmes for more information.

The target board for this project is the 
[TinyFPGA BX](https://github.com/tinyfpga/TinyFPGA-BX)




