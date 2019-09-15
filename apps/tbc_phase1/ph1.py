#!/usr/bin/env python3
import socket
import sys
import time
import select

def s16(value):
    """
    Helper function to convert 16-bit to signed
    """
    return -(value & 0x8000) | (value & 0x7fff)

class Tablebot:
    STATE_IDLE = "IDLE";
    STATE_MOVE = "MOVE";
    STATE_STOP = "STOP";
    STATE_BACK = "BACK";
    STATE_TURN = "TURN";



    def __init__(self):
        # Start sock_cmd connection
        self.sock_cmd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock_cmd.connect(('localhost', 8870))

        # Start hba_qtr cat
        self.sock_qtr_cat = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock_qtr_cat.connect(('localhost', 8870))
        self.set_cmd(b'hbaset hba_qtr period 0\n')
        self.set_cmd(b'hbaset hba_qtr thresh 1f\n')
        self.set_cmd(b'hbaset hba_qtr ctrl f\n')
        self.sock_qtr_cat.send(b'hbacat hba_qtr qtr\n')

        # Start hba_quad cat
        self.sock_quad_cat = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock_quad_cat.connect(('localhost', 8870))
        self.set_cmd(b'hbaset hba_quad ctrl 7\n')
        self.sock_quad_cat.send(b'hbacat hba_quad enc1\n')

        # Setup select loop inputs, and outputs
        self.inputs = [ self.sock_qtr_cat,  self.sock_quad_cat]
        self.outputs = [ ]

        # Initialize the state
        self.state = self.STATE_MOVE;
        self.prev_state = self.STATE_IDLE;

        # Init done
        self.done = False

        # Last sensor values
        self.last_qtr0 = None
        self.last_qtr1 = None
        self.last_quad = None


    def set_cmd(self, set_str):
        self.sock_cmd.send(set_str)
        while True:
            retval = self.sock_cmd.recv(1)
            if retval == b'\\':
                break

        

    def get_cmd(self, get_str):
        self.sock_cmd.send(get_str)
        data = ""
        while True:
            retval = self.sock_cmd.recv(1)
            if retval == b'\\':
                break
            elif retval == b'\n':
                pass
            else:
                data = data + retval
        return data

    def read_qtr(self):
        data = b''
        while True:
            retval = self.sock_qtr_cat.recv(1)
            if retval == b'\n':
                break
            else:
                data = data + retval
        (tmp0, tmp1) = data.split()
        self.last_qtr0 = int(tmp0,16)
        self.last_qtr1 = int(tmp1,16)

    def read_quad(self):
        data = b''
        while True:
            retval = self.sock_quad_cat.recv(1)
            if retval == b'\n':
                break
            else:
                data = data + retval
        self.last_quad = s16(int(data,16))
        #print("last_quad: ", self.last_quad)



    def robot_out(self):
        if (self.state != self.prev_state):
            print("new state: ",self.state)
            new_state = True
        else:
            new_state = False

        if self.state == self.STATE_MOVE:
            self.set_cmd(b'hbaset hba_motor motor0 10\n')
            self.set_cmd(b'hbaset hba_motor motor1 10\n')
            self.set_cmd(b'hbaset hba_motor mode ff\n')
        elif self.state == self.STATE_STOP:
            self.set_cmd(b'hbaset hba_motor mode bb\n')
        elif self.state == self.STATE_TURN:
            self.set_cmd(b'hbaset hba_motor mode rf\n')
        elif self.state == self.STATE_BACK:
            self.set_cmd(b'hbaset hba_motor mode rr\n')


        self.prev_state = self.state

    def robot_trans(self):
        if self.state == self.STATE_MOVE:
            if self.last_qtr0 == 255 or self.last_qtr1 == 255:
                self.start_quad = self.last_quad
                self.end_quad = self.last_quad - 50
                print("start_quad: ", self.start_quad)
                print("end_quad: ", self.end_quad)
                self.state = self.STATE_BACK
        elif self.state == self.STATE_BACK:
            if self.last_quad < self.end_quad:
                print("end_back last_quad: ", self.last_quad)
                self.start_quad = self.last_quad
                self.end_quad = self.last_quad + 720
                self.state = self.STATE_TURN
        elif self.state == self.STATE_TURN:
            if self.last_quad > self.end_quad:
                print("end_turn last_quad: ", self.last_quad)
                self.state = self.STATE_MOVE
            pass
        elif self.state == self.STATE_STOP:
            pass


    def run(self):
        """
        Implements the Select loop
        """
        try:
            while not self.done:
                self.robot_out()
                readable, writable, exceptional = select.select(self.inputs,
                        self.outputs, self.inputs)
                for sock in readable:
                    if sock == self.sock_quad_cat:
                        self.read_quad()
                    elif sock == self.sock_qtr_cat:
                        self.read_qtr()

                self.robot_trans()
        finally:
            print("Turn off leds and motors")
            self.set_cmd(b'hbaset hba_basicio leds 0\n')
            self.set_cmd(b'hbaset hba_motor mode bb\n')
            self.sock_cmd.close()
            self.sock_quad_cat.close()
            self.sock_qtr_cat.close()
            print("Exit normal.")


# Start running here at main
if __name__ == "__main__":

    tb = Tablebot()
    tb.run()



