# basicio_test

## Description

This project implements the serial_fpga master in slot0.
The serial_fpga also implements a slave interface
in which you can read back the interrupt register
to see if any slaves asserted an interrupt.

It implements hba_basicio peripheral in slot1.
This peripheral provides control of up to
8 leds and 8 buttons.

See the serial_fpga and hba_basicio readmes for more information.


