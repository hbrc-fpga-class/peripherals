#!/usr/bin/env python
import socket
import sys
''' This program opens two sockets to the hbadaemon, one
    to listen for gamepad events and one to update the
    leds.  This code uses a blocking read but a select()
    implementation would work too.
'''

# Send a set command to the fpga and wait for the reponse prompt
def set_cmd(sock, set_str):
    sock.send(set_str)
    while True:
        retval = sock.recv(1)
        if retval == '\\':
            break


try:
    sock_cmd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_cmd.connect(('localhost', 8870))
    sock_gamepad = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_gamepad.connect(('localhost', 8870))
    set_cmd(sock_gamepad, 'hbaset gamepad filter edffff\n')
    sock_gamepad.send('hbacat gamepad state\n')
    # loop forever getting gamepad joystick positions  
    while True:
        gamepad_state= sock_gamepad.recv(1024).split()
        # Gamepad analog controls output a value between -32767 and
        # +32767.  Map this range to a range of 0 to 15.
        leftleds = 15 - ((int(gamepad_state[1]) + 32767) / 4096)
        rightleds = 15 - ((int(gamepad_state[2]) + 32767) / 4096)
        # Combine the two four bit value and send to the LEDs
        hexleds = format((leftleds * 16) + rightleds, '02x')
        set_cmd(sock_cmd, 'hbaset hba_basicio leds '+hexleds+'\n')


except KeyboardInterrupt:
    # exit on Ctrl^C
    sock_cmd.close()
    sock_gamepad.close()
    sys.exit()

except socket.error:
    print "Couldn't connect to hbadaemon"
    sys.exit()


