============================================================

HARDWARE

This module provides an interface to two
quatrature encoders.  This module senses the direction
and increments or decrements the encoder count as appropriate.
Each encoder count is a 16-bit value, stored in two
8-bit registers.  It is recommended to disable the encoder
updates before reading the encoder values.  Then re-enable
encoder updates after the values are read.  The encoder
counts will still be updated internally only the updating
to the register bank is paused.

RESOURCES

ctrl : This get/set the control register.
    - Bit 0 : Enable left encoder register updates
    - Bit 1 : Enable right encoder register updates
    - Bit 2 : Enable interrupt.
    - Bit 3 : Reset both encoders by writing 1. Not auto-cleared.  Suggest using the
              reset resource below instead of setting this bit directly.

This resource works with hbaget and hbaset.
The startup value is 0, with everything disabled.
Example values:
    - 3 : Enable left and right encoder updates, no interrupt.
    - 7 : Enable left and right encoder updates, AND enable interrupt.

enc0 : Reads 16-bit left encoder value.  Handles disabling
updates, reading LSB and MSB, and assembling the value.
Then restores the ctrl value back to saved value.
This resource works with hbaget and hbacat.

enc1 : Reads 16-bit right encoder value.  Handles disabling
updates, reading LSB and MSB, and assembling the value.
Then restores the ctrl value back to saved value.
This resource works with hbaget and hbacat.

enc : Reads both encoder values. Formats as 'enc0 enc1'.
This resource works with hbaget and hbacat.

reset : Resets both encoder values back to zero. Autocleared by the driver.
This resource works with hbaset.

speed_period : A period in ms.  Valid range 0..255ms. Encoder ticks are
counted during this period to infer speed. Default 0 (disabled).
This resource works with hbaset.

speed : Read both encoder speed values. Formats as 'speed_left speed_right'.
This is the number of encoder ticks during the last speed_period.
This resource works with hbaget and hbacat.


EXAMPLES
Enable updates and interrupts
Read the the 16-bit left encoder value
Read the the 16-bit right encoder value
Start a stream of encoder values from the left sensor

 hbaset hba_quad ctrl 7
 hbaset hba_quad reset 1
 hbaget hba_quad enc
 hbacat hba_quad enc

