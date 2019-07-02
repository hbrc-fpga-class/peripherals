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

EXAMPLES
Enable updates and interrupts
Read the the 16-bit left encoder value
Read the the 16-bit right encoder value

 hbaset hba_qtr ctrl 3
 hbaset hba_qtr enc0
 hbaset hba_qtr enc1

