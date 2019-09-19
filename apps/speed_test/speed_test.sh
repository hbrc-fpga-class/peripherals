#!/bin/bash

# Setup the edge sensors
`hbaset hba_qtr period 0`
# `hbaset hba_qtr thresh 1f`
`hbaset hba_qtr ctrl 1`

# Setup the hba_quad
`hbaset hba_quad ctrl 3`
`hbaset hba_quad reset 1`

# Setup the motor
`hbaset hba_motor mode bb`
`hbaset hba_motor motor0 0a`    #10
`hbaset hba_motor motor1 0a`
`hbaset hba_motor mode ff`

# Ramp up the speed
sleep 0.2
`hbaset hba_motor motor0 14`   #20
`hbaset hba_motor motor1 14`

sleep 0.2
`hbaset hba_motor motor0 1e`   #30
`hbaset hba_motor motor1 1e`

#sleep 0.2
#`hbaset hba_motor motor0 28`   #40
#`hbaset hba_motor motor1 28`

#sleep 0.2
#`hbaset hba_motor motor0 32`   #50
#`hbaset hba_motor motor1 32`

#sleep 0.2
#`hbaset hba_motor motor0 3c`   #60
#`hbaset hba_motor motor1 3c`

#sleep 0.2
#`hbaset hba_motor motor0 46`   #70
#`hbaset hba_motor motor1 46`

#sleep 0.2
#`hbaset hba_motor motor0 50`   #80
#`hbaset hba_motor motor1 50`

#sleep 0.2
#`hbaset hba_motor motor0 5a`   #90
#`hbaset hba_motor motor1 5a`

#sleep 0.2
#`hbaset hba_motor motor0 64`   #100
#`hbaset hba_motor motor1 64`

# Reset the encoder
`hbaset hba_quad reset 1`

# Continue for another second
sleep 1.0

# print out the encoder count
echo `hbaget hba_quad enc`

# Stop the motors
`hbaset hba_motor mode bb`

