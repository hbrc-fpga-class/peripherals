#!/usr/bin/env python
import socket
import sys
import time

# This program reads values from the sonar and displays
# them on the leds.

RANGE = 3
count = 0;

try:
    sock_sonar = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_sonar.connect(('localhost', 8870))

    sock_led = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_led.connect(('localhost', 8870))

    # Make sure we are talking to the correct serial port
    # sock_sonar.send('hbaset serial_fpga port /dev/ttyUSB1\n')

    # Make sure the sonar0 is turned on
    sock_sonar.send('hbaset hba_sonar ctrl 1\n')

    time.sleep(0.5)

    # loop forever 
    while True:
        sock_sonar.send('hbaget hba_sonar sonar0\n')
        line = sock_sonar.recv(6)
        dist = line.splitlines()[0]
        if '\\' in dist:
            continue
        if dist == '':
            continue
        dist_int = int(dist[:4],16)
        if dist_int == 0:
            continue
        print "dist_int: %d" % dist_int

        #sock_led.send('hbaset hba_basicio leds ' "%x" '\n' % count)
        #count = (count + 1) % 256

        if dist_int < (RANGE*1):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x01)
        elif dist_int < (RANGE*2):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x03)
        elif dist_int < (RANGE*3):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x07)
        elif dist_int < (RANGE*4):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x0f)
        elif dist_int < (RANGE*5):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x1f)
        elif dist_int < (RANGE*6):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x3f)
        elif dist_int < (RANGE*7):
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0x7f)
        else:
            sock_sonar.send('hbaset hba_basicio leds ' "%x" '\n' % 0xff)

        time.sleep(0.15)


except KeyboardInterrupt:
    # exit on Ctrl^C
    sock_sonar.close()
    sys.exit()

except socket.error:
    print "Couldn't connect to hbaserver"
    sys.exit()

