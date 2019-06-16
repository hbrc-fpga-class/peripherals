#!/usr/bin/env python
import socket
import sys
import time

# This program reads values from the sonar and displays
# them on the leds.

RANGE = 3

try:
    sock_cmd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_cmd.connect(('localhost', 8870))

    # loop forever 
    while True:
        sock_cmd.send('hbaget hba_sonar sonar0\n')
        line = sock_cmd.recv(6)
        dist = line.splitlines()[0]
        if '\\' in dist:
            continue
        if dist == '':
            continue
        dist_int = int(dist[:4],16)
        if dist_int == 0:
            continue
        print "dist_int: %d" % dist_int
        if dist_int < (RANGE*1):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x01)
        elif dist_int < (RANGE*2):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x03)
        elif dist_int < (RANGE*3):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x07)
        elif dist_int < (RANGE*4):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x0f)
        elif dist_int < (RANGE*5):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x1f)
        elif dist_int < (RANGE*6):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x3f)
        elif dist_int < (RANGE*7):
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0x7f)
        else:
            sock_cmd.send('hbaset hba_basicio leds ' "%x" '\n' % 0xff)

        time.sleep(0.05)

except KeyboardInterrupt:
    # exit on Ctrl^C
    sock_cmd.close()
    sys.exit()

except socket.error:
    print "Couldn't connect to hbaserver"
    sys.exit()

