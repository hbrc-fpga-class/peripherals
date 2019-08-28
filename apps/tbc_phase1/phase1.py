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

def set_cmd(sock, set_str):
    sock.send(set_str)
    while True:
        retval = sock.recv(1)
        if retval == b'\\':
            break

def get_cmd(sock, get_str):
    sock.send(get_str)
    data = ""
    while True:
        retval = sock.recv(1)
        if retval == b'\\':
            break
        elif retval == b'\n':
            pass
        else:
            data = data + retval
    return data

class Behav_Forward:
    """
    A Behavior for moving forward
    """
    def __init__(self, sock_):
        self.sock = sock_
        set_cmd(self.sock, b'hbaset hba_motor motor0 10\n')
        set_cmd(self.sock, b'hbaset hba_motor motor1 10\n')
        set_cmd(self.sock, b'hbaset hba_motor mode bb\n')
        self.enable = False

    def run(self):
        if self.enable:
            set_cmd(self.sock, b'hbaset hba_motor mode ff\n')


class Behav_Stop_At_Edge:
    """
    A Behavior for stoping when edge of table is detected
    """
    def __init__(self, sock_):
        self.sock = sock_
        set_cmd(self.sock, b'hbaset hba_qtr period 1\n')
        set_cmd(self.sock, b'hbaset hba_qtr ctrl 7\n')
        self.enable = False

    def run(self):
        state = "table"
        while True:
            qtr_value = yield state
            if self.enable and qtr_value == b'ff':
                set_cmd(sock, b'hbaset hba_motor mode bb\n')
                state = "edge"
                print("   EDGE!!!")
            else:
                state = "table"

class Behav_Rotate_180:
    """
    A Behavior to rotate the robot 180 degrees
    """
    def __init__(self, sock_):
        self.sock = sock_
        self.enable = False

    def run(self):
        state = "turning"
        while True:
            enc_value = yield state
            if self.enable and enc_value == self.target:
                state = "done"
                set_cmd(sock, b'hbaset hba_motor mode bb\n')
                print("   Done Turning")
            else:
                state = "turning"

    

def c_check_edge(sock):
    state = "table"
    while True:
        qtr_value = yield state
        print("qtr_value: ",qtr_value)
        if qtr_value == b'ff':
            set_cmd(sock, b'hbaset hba_motor mode bb\n')
            state = "edge"
            print("   EDGE!!!")



# Start running here at main
if __name__ == "__main__":

    # Connect to the hbadaemon
    try:
        print("Create sock_hba")
        sock_hba = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_hba.connect(('localhost', 8870))

        # create socket for cat hba_qtr0
        print("Create sock_catqtr0")
        sock_catqtr0 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_catqtr0.connect(('localhost', 8870))

        # create socket for cat hba_qtr1
        print("Create sock_catqtr1")
        sock_catqtr1 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_catqtr1.connect(('localhost', 8870))

        # Turn on some leds
        print("Turn on some leds")
        set_cmd(sock_hba, b'hbaset hba_basicio leds 7\n')

        # init hba_qtr
        print("init hba_qtr")
        set_cmd(sock_hba, b'hbaset hba_qtr period 1\n')
        set_cmd(sock_hba, b'hbaset hba_qtr ctrl 7\n')

        # init hba_motor
        print("init hba_motor")
        set_cmd(sock_hba, b'hbaset hba_motor mode bb\n')

        # Start the hba_qtr0 cat
        print("init hba_qtr0")
        set_cmd(sock_catqtr0, b'hbaset hba_qtr period 1\n')
        set_cmd(sock_catqtr0, b'hbaset hba_qtr ctrl 7\n')
        sock_catqtr0.send(b'hbacat hba_qtr qtr0\n')

        # Start the hba_qtr1 cat
        print("init hba_qtr1")
        sock_catqtr1.send(b'hbacat hba_qtr qtr1\n')

        # Sockets from which we expect to read
        inputs = [ sock_catqtr0, sock_catqtr1 ]

        # Sockets to which we expect to write
        outputs = [ ]

        # Init coroutines
        check_edge = c_check_edge(sock_hba)
        next(check_edge)    # Prime the coroutine


        # Turn on motors
        print("Start while loop:")
        set_cmd(sock_hba, b'hbaset hba_motor motor0 10\n')
        set_cmd(sock_hba, b'hbaset hba_motor motor1 10\n')
        set_cmd(sock_hba, b'hbaset hba_motor mode ff\n')

        done = False
        while not done:
            print("Waiting for the next event")
            readable, writable, exceptional = select.select(inputs, outputs, inputs)
            for sock in readable:

                if sock == sock_catqtr0:
                    print("qtr0")
                elif sock == sock_catqtr1:
                    print("qtr1")

                data = b''
                while True:
                    retval = sock.recv(1)
                    if retval == b'\n':
                        break
                    else:
                        data = data + retval
                print("   data: %s " % data)
                check_edge.send(data)
                #if data==b'ff':
                #    set_cmd(sock_hba, b'hbaset hba_motor mode bb\n')
                #    print("   EDGE!!!")
                #    done = True


            #try:
            #    done = test.menu()
#
#            except KeyboardInterrupt:
#                # Show menu again when ctrl-c
#                print
#                print("ctrl-c interrupt")
#                test.motor_stop()
#                test.set_cmd("hbaset hba_basicio leds 0\n")
#                continue

    except socket.error:
        print("Couldn't connect to hbaserver")
        sys.exit()

    finally:
        print("Turn off leds and motors")
        set_cmd(sock_hba, b'hbaset hba_basicio leds 0\n')
        set_cmd(sock_hba, b'hbaset hba_motor mode bb\n')
        print("Exit normal.")
        sock_hba.close()
        sock_catqtr0.close()

