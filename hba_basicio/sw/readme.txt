============================================================

HARDWARE
   The hba_basicio peripheral  gives direct access to 
up to 8 leds and 8 buttons. The buttons can be configured
to trigger an interrupt if any of the buttons change state.


RESOURCES
leds : The value on the leds. Each bit of this of this 8-bit
value controls one led.  If the bit is set to 1 the led is on,
if it is set to zero the led is off.
This resource works with hbaget and hbaset.

buttons : Reading this resource gives you the current state of
the buttons.  Each bit of this 8-bit value represents a
buttons state.  The buttons are active low . A bit value of 1
means the button is not pressed (up state). A bit value of 0
means the button is pressed (down state). 
This resource works with hbaget. If interrupts are enabled
then it works with hbacat as well.

intr : The interrupt enable mask.  When set to 1
button interrupts are enabled (i.e. an interrupt is generated
when any button changes state).  When set to 0 the button
interrupts are disabled.

EXAMPLES
Turn on every other led in the pattern 1010_1010.
Invert the leds in the pattern  ...    0101_0101.
Read the current value of the buttons.
Enable the button interrupts.
Echo any changes on the buttons.

 hbaset hba_basicio leds aa
 hbaset hba_basicio leds 55
 hbaget hba_basicio buttons
 hbaset hba_basicio intr 1
 hbacat hba_basicio buttons


