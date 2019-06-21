# hba_motor

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It provides an interface to control two motor driver circuits.
For each motor there is a pwm and a direction signal.
The pwm is generated at 100khz.  The width of the pwm
signal controls the speed of the motor.

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

* __motor_pwm[1:0]__ (output) : The pwm signal for motor speed
* __motor_dir[1:0]__ (output) : The direction signal.
* __motor_sleep_n[1:0]__ (output) : Asserting (active low) this signal puts the motor in coast mode.


## Register Interface

There are four 8-bit registers.

* __reg0__ : Control register. Enables motor
    * reg0[0] : Enable motor 0.
    * reg0[1] : Enable motor 1.
* __reg1__ : Coast registers
    * reg1[0] : Motor 0 coast. Active=0, Coast=1
    * reg1[1] : Motor 1 coast. Active=0, Coast=1
* __reg2__ : Motor 0 speed and direction
    * reg2[6:0] : Motor 0 duty cycle.  0 (stop) ... 100 (full speed)
    * reg2[7] : Motor 0 coast. Active=0, Coast=1
* __reg3__ : Motor 1 speed and direction
    * reg2[6:0] : Motor 1 duty cycle.  0 (stop) ... 100 (full speed)
    * reg2[7] : Motor 1 coast. Active=0, Coast=1

## TODO

* Perhaps add control bits to put it into locked-anti-phase mode.

