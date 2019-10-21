# hba_demo

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
This is a very cool module. That does some very neat things. I can't think of what that is right now.

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __slave_interrupt__ (output) : Asserted when button state changes and the
  interrupt is enabled.
* __basicio_led[7:0]__ (output) : The 8-bit led port.
* __basicio_button[7:0]__ (input) : The 2-bit button port.

## Register Interface

There are three 8-bit registers.

* __reg0__(r) : (reg_ctrl) - bit0 is the interrupt enable.
* __reg1__(w) : (reg_out) - This is the main output.
