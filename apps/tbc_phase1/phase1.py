#!/usr/bin/env python3
import socket
import sys
import time
import select
"""
This program implements phase 1 of the
HBRC Tablebot challenge.  It drives
forward to the end of the table, then turns
around and heads back.
"""

class Phase1:
    """
    Implement phase1.
    """

    def __init__(self, sock_hba_):
        self.sock_hba = sock_hba_

        # init hba_qtr
        self.set_cmd('hbaset hba_qtr period 1\n')
        self.set_cmd('hbaset hba_qtr ctrl 7\n')

        # init hba_motor
        self.set_cmd('hbaset hba_motor mode bb\n')
        

    def set_cmd(self, set_str):
        self.sock_hba.send(set_str)
        while True:
            retval = self.sock_hba.recv(1)
            if retval == '\\':
                break

    def get_cmd(self, get_str):
        self.sock_hba.send(get_str)
        data = ""
        while True:
            retval = self.sock_hba.recv(1)
            if retval == '\\':
                break
            elif retval == '\n':
                pass
            else:
                data = data + retval
        return data

# Start running here at main
if __name__ == "__main__":

    # Connect to the hbadaemon
    try:
        sock_hba = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_hba.connect(('localhost', 8870))

        # Create Romi_Test object
        phase1 = Phase1(sock_hba)

        done = False
        while not done:
            try:
                done = test.menu()

            except KeyboardInterrupt:
                # Show menu again when ctrl-c
                print
                print("ctrl-c interrupt")
                test.motor_stop()
                test.set_cmd("hbaset hba_basicio leds 0\n")
                continue

    except socket.error:
        print("Couldn't connect to hbaserver")
        sys.exit()

    finally:
        print("Exit normal.")
        sock_hba.close()

