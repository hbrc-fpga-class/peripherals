# gpio_test

## Description

This project implements the serial_fpga master in slot0.
The serial_fpga also implements a slave interface
in which you can read back the interrupt register
to see if any slaves asserted an interrupt.

It implements hba_gpio peripheral in slot1.
This peripheral control 4 GPIO pins, allowing
the master to read or write to those pins.

See the serial_fpga and hba_gpio readmes for more information.

The target board for this project is the 
[TinyFPGA BX](https://github.com/tinyfpga/TinyFPGA-BX)




