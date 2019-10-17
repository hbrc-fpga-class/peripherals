# hba_speed_ctrl

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It enables a simple speed controller.

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __speed_ctrl_actual_lspeed[7:0]__ (input) : Encoder speed of left motor
* __speed_ctrl_actual_rspeed[7:0]__ (input) : Encoder speed of right motor
* __speed_ctrl_actual_pulse[7:0]__ (input) : Encoder speed update pulse
* __speed_ctrl_lpwm[7:0]__ (output) : The pwm value for left motor
* __speed_ctrl_rpwm[7:0]__ (output) : The pwm value for right motor

## Register Interface

There are three 8-bit registers.

* __reg0__ : (reg_desired_lspeed) - Left speed in encoder ticks per period.
* __reg1__ : (reg_desired_rspeed) - Right speed in encoder ticks per period.
* __reg2__ : (reg_init_lpwm) - Initial left pwm duty cycle.
* __reg3__ : (reg_init_rpwm) - Initial right eft pwm duty cycle.

