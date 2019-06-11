# hba_basicio

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It provides an interface to control some "Basic IO".
The Basic IO items are:
* 8 LEDs
* 8 Buttons

**Note** : A given board may not have 8 leds
or 8 buttons, so the parent module may tie these
off as appropriate. 

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __slave_interrupt__ (output) : Asserted when button state changes and the
  interrupt is enabled.
* __basicio_led[7:0]__ (output) : The 8-bit led port.
* __basicio_button[7:0]__ (input) : The 2-bit button port.

## Register Interface

There are three 8-bit registers.

* __reg0__ : The value to write to the LEDs.
* __reg1__ : The button value.
* __reg2__ : Interrupt Enable Register. A value of 1 indicates that
change in button state will cause an interrupt.

