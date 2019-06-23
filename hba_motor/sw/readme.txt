============================================================

HARDWARE

The hba_motor peripheral provides an interface to control 
a dual motor motor controller such as the TI DRV8838.
For each motor channel there are pwm, direction, and float_n
signals.


RESOURCES

mode : This get/set the mode register. The value for the mode
is a string of 2 characters such as 'bb'.  The first character
is for the left motor and the second character is for the right
motor.  Valid characters are 'b' for brake, 'f' for forward,
'r' for reverse, 'c' for coast.  Here are some example values:
    - 'bb' : Brake left and right motors. Stop
    - 'ff' : Forward left and right motors. Move Forward
    - 'fr' : Forward left, reverse right. Turn right
    - 'rf' : Reverse left, forward right. Turn left
    - 'rr' : Reverse left, Reverse right. Move Back
    - 'cc' : Coast left and right motors.
This resource works with hbaget and hbaset.

motor0 : Set the power and direction for motor 0.
    - 0-100   : Duty cycle in the forward direction. 0=Off, 100=full power
This resource works with hbaget and hbaset.

motor1 : Set the power and direction for motor 1.
    - 0-100   : Duty cycle in the forward direction. 0=Off, 100=full power
This resource works with hbaget and hbaset.


EXAMPLES
Stop motors (brake)
Set motor power to 10%
Spin clockwise

 hbaset hba_motor mode bb
 hbaset hba_motor motor0 10
 hbaset hba_motor motor1 10
 hbaset hba_motor mode fr


