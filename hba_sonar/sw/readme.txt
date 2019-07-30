============================================================

HARDWARE

The hba_sonar peripheral provides an interface to control two
SR04 sonars.  There is a control register that can be used
to enable each sonar independently. There is a sonar0_val
register and a sonar1_val register that reads the last
recorded sonar values.

This peripheral generates an interrupt when the sonar(s) fire.
In the future there will be a register to disable the interrupt.

RESOURCES

ctrl : This get/set the control register.  Here are the 
currently support values:
    - 0 : Disable both sonars
    - 1 : Enable Sonar 0.
    - 2 : Enable Sonar 1.
    - 3 : Enable both Sonar0 and Sonar1.
This resource works with hbaget and hbaset.

sonar0 : Reads the last sonar0 value.
This resource works with hbaget and hbacat.

sonar1 : Reads the last sonar1 value.
This resource works with hbaget and hbacat.


EXAMPLES
Enable only Sonar 0.
Read back the value of Sonar 0.
Echo back new sonar 0 values.

 hbaset hba_sonar ctrl 1
 hbaget hba_sonar sonar0
 hbacat hba_sonar sonar0

