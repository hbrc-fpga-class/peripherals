char README[] = "\
============================================================\n\
\n\
HARDWARE\n\
   The hba_basicio peripheral  gives direct access to \n\
up to 8 leds and 8 buttons. The buttons can be configured\n\
to trigger an interrupt if any of the buttons change state.\n\
\n\
\n\
RESOURCES\n\
leds : The value on the leds. Each bit of this of this 8-bit\n\
value controls one led.  If the bit is set to 1 the led is on,\n\
if it is set to zero the led is off.\n\
This resource works with hbaget and hbaset.\n\
\n\
buttons : Reading this resource gives you the current state of\n\
the buttons.  Each bit of this 8-bit value represents a\n\
buttons state.  The buttons are active low . A bit value of 1\n\
means the button is not pressed (up state). A bit value of 0\n\
means the button is pressed (down state). \n\
This resource works with hbaget. If interrupts are enabled\n\
then it works with hbacat as well.\n\
\n\
intr : The interrupt enable mask.  When set to 1\n\
button interrupts are enabled (i.e. an interrupt is generated\n\
when any button changes state).  When set to 0 the button\n\
interrupts are disabled.\n\
\n\
EXAMPLES\n\
Turn on every other led in the pattern 1010_1010.\n\
Invert the leds in the pattern  ...    0101_0101.\n\
Read the current value of the buttons.\n\
Enable the button interrupts.\n\
Echo any changes on the buttons.\n\
\n\
 hbaset hba_basicio leds aa\n\
 hbaset hba_basicio leds 55\n\
 hbaget hba_basicio buttons\n\
 hbaset hba_basicio intr 1\n\
 hbacat hba_basicio buttons\n\
\n\
\n\
";
