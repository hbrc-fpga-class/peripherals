============================================================

HARDWARE
   The hba_gpio peripheral  gives direct access to each of
four pins on the FPGA.  Each GPIO pin can be an input or an
output, and changes at an input pin can trigger an interrupt.
(TBD : pin numbering to bits in hba_gpio resources)


RESOURCES
val : The value on the GPIO pins.  A write to this resource
sets an output pin, and a read from it returns the current
value on the pins.  A read requires a round trip over the
USB-serial link and may take a few milliseconds.  Data is
given as a hexadecimal number.  You can monitor the pins
using a hbacat command.  Using hbacat only makes sense if one
or more of the pins are configured as input and as a source
of interrupts.

dir : The direction of the four pins as a hexadecimal digit.
A set bit makes the pin an output and a cleared bit makes it
an input.  The power up default is for all pins to be inputs.
This resource works with hbaget and hbaset.

inter : The interrupt enable mask.  When a pin is an input
and the interrupt bit is set for that pin, when the logic
level of the pin changes, the FPGA sets a bit in the interrupt
request register of the serial_fpga peripheral.  This in
turn causes the value of the GPIO value register to be read
and the value sent to any listening channels set up with a
hbacat command.


EXAMPLES
Make the low two pins inputs and the high two pins outputs.
Set both output pins high.  Enable interrupt-on-change for
the two input pins.  Use hbacat to start a data stream of
changed inputs on the GPIO port.

 hbaset hba_gpio dir c
 hbaset hba_gpio val c
 hbaset hba_gpio intr 3
 hbacat hba_gpio val


