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

        # Start basicio_cat
        self.sock_basicio_cat = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock_basicio_cat = connect(('localhost', 8870))
        self.sock_basicio_cat.send(b'hbacat hba_basicio buttons\n')

        # Setup select loop inputs, and outputs
        self.inputs = [ self.sock_basicio_cat ]
        self.outputs = [ ]

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

    def get_data(self, sock):
        """
        Get data from a socket who's last cmd was a hbacat
        """
        data = b''
        while True:
            retval = sock.recv(1)
            if retval == b'\n':
                break
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

    def select_loop(self):
        while True:
            readable, writable, exceptional = select.select(inputs, outputs, inputs)
            # loop through all the sockets available for reading
            for sock in readable:
                if sock == self.sock_basicio_cat:
                    # read the data
                    data = self.get_data(self.sock_basicio_cat)

                    # loop through all basicio listeners and send the data
                    for listener in self.basicio_listener
                        listener.send(data)








