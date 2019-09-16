# hba_motor

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It provides an interface to control two motor driver circuits.
For each motor there is a pwm and a direction signal.
The pwm is generated at 100khz.  The width of the pwm
signal controls the power of the motor.

The motor driver used by the Romi platform for the HBRC class
is the TI DRV8838.  This peripheral was developed with this
motor driver in mind, but it most likely will work with 
many others.

The convention is for:
* Motor 0 is the Left motor
* Motor 1 is the Right motor

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __motor_pwm[1:0]__ (output) : The pwm signal for motor power
* __motor_dir[1:0]__ (output) : The direction signal.
* __motor_float_n[1:0]__ (output) : Asserting (active low) this signal puts the motor in float/coast mode.
* __motor_estop[15:0]__ (input) : Emergency stop coming from the peripherals.


## Register Interface

There are three 8-bit registers.

* __reg0__ : Mode register. Sets the mode for both motors
    * reg0[0] : Enable motor 0. 0=Brake, 1=Active
    * reg0[1] : Enable motor 1. 0=Brake, 1=Active
    * reg0[2] : Direction motor 0. 0=Forward, 1=Reverse
    * reg0[3] : Direction motor 1. 0=Forward, 1=Reverse
    * reg0[4] : Coast/Float motor 0. 0=Not Coast, 1=Coast
    * reg0[5] : Coast/Float motor 1. 0=Not Coast, 1=Coast
* __reg1__ : Motor 0 power and direction
    * reg1[7:0] : Motor 0 duty cycle.  0 (stop) ... 100 (full power)
                Values greater than 100 are ignored.
* __reg2__ : Motor 1 power and direction
    * reg2[7:0] : Motor 1 duty cycle.  0 (stop) ... 100 (full power)
                Values greater than 100 are ignored.

## TODO

* Add ramp speed register.
* Perhaps add control bits to put it into locked-anti-phase mode.

