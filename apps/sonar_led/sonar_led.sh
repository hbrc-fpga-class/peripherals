#!/bin/bash
RANGE=3
while true
do
    val=`hbaget hba_sonar sonar0`
    val=$(( 16#$val ))
    echo $val
    if [ $val -lt $(( $RANGE*1 )) ]; then
        `hbaset hba_basicio leds 1`
    elif [ $val -lt $(( $RANGE*2 )) ]; then
        `hbaset hba_basicio leds 3`
    elif [ $val -lt $(( $RANGE*3 )) ]; then
        `hbaset hba_basicio leds 7`
    elif [ $val -lt $(( $RANGE*4 )) ]; then
        `hbaset hba_basicio leds f`
    elif [ $val -lt $(( $RANGE*5 )) ]; then
        `hbaset hba_basicio leds 1f`
    elif [ $val -lt $(( $RANGE*6 )) ]; then
        `hbaset hba_basicio leds 3f`
    elif [ $val -lt $(( $RANGE*7 )) ]; then
        `hbaset hba_basicio leds 7f`
    else
        `hbaset hba_basicio leds ff`
    fi
    sleep 0.1
done

