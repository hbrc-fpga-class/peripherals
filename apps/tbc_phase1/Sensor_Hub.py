import socket
import sys
import time
import select


class Sensor_Hub:
    """
    This class implements a select loop to
    read and distribute sensor values coming
    from interrupts.
    """

    def __init__(self, sock_cmd_):
        self.sock_cmd = sock_cmd_

        self.basicio_listener   = []
        self.qtr_listener       = []
        self.sonar_listener     = []
        self.quad_listener      = []
        self.gamepad_listener   = []

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


    def add_basicio_listener(coroutine):
        # check if basicio_listener is empty
        if not self.basicio_listener:
            # enable interrupts
            self.set_cmd(b'hbaset hba_basicio intr 1')

        # add the coroutine to the list
        self.basicio_listener.add(coroutine)

    def rm_basicio_listener(coroutine):
        # remove the coroutine
        self.basicio_listener.remove(coroutine)

        # Check if list empty, if it is turn off interrupt
        if not self.basicio_listener:
            # disable interrupts
            self.set_cmd(b'hbaset hba_basicio intr 0')






