============================================================

HARDWARE

The hba_motor peripheral provides an interface to control 
a dual motor motor controller such as the TI DRV8838.
For each motor channel there are pwm, direction, and float_n
signals.  All of these signals can be controlled via
the register interface.


RESOURCES

ctrl : This get/set the control register.  Here are the 
currently support values:
    - 0 : Disable both motors (brake) (Default)
    - 1 : Enable Motor 0 (left by convention).
    - 2 : Enable Motor 1 (right by convention).
    - 3 : Enable both Motors
This resource works with hbaget and hbaset.

float : This get/set the float register.  Here are the
currently support values:
    - 0 : Both motors in active mode (not floating) (Default)
    - 1 : Motor 0 in float/coast mode.
    - 2 : Motor 1 in float/coast mode.
    - 3 : Both motors in float/coast mode.
This resource works with hbaget and hbaset.

motor0 : Set the power and direction for motor 0.
    - 0-100   : Duty cycle in the forward direction. 0=Off, 100=full power
    - 128-228 : Duty cycle in the reverse direction. 128=Off, 228=full power
This resource works with hbaget and hbaset.

motor1 : Set the power and direction for motor 1.
    - 0-100   : Duty cycle in the forward direction. 0=Off, 100=full power
    - 128-228 : Duty cycle in the reverse direction. 128=Off, 228=full power
This resource works with hbaget and hbaset.


EXAMPLES
Enable both motors
Drive forward at half power

 hbaset hba_sonar motor0 50
 hbaset hba_sonar motor1 50
 hbaset hba_sonar ctrl 3


