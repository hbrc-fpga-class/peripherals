#!/usr/bin/env python
import socket
import sys
import time

# This program has a menu interface for testing all
# of the romi peripherals.

class Romi_Test:
    """
    Peripherals tests for the Romi Platform
    """

    def __init__(self, sock_hba_):
        self.sock_hba = sock_hba_

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

    def serial_info(self):
        port = self.get_cmd('hbaget serial_fpga port\n')
        config = self.get_cmd('hbaget serial_fpga config\n')
        print("Serial Configuration:")
        print "   port:   ", port
        print "   config: ",config

    def motor_stop(self):
        self.set_cmd('hbaset hba_motor mode bb\n')

    def qtr_test(self, seconds):
        # Init hba_qtr
        # Set the trigger period to 100ms.
        self.set_cmd('hbaset hba_qtr period 1\n')
        # Enable both qtr0 and qtr1, no interrupt
        self.set_cmd('hbaset hba_qtr ctrl 3\n')

        start = time.time()
        end = time.time()
        run_time = end - start
        while run_time < seconds:
            qtr0 = self.get_cmd('hbaget hba_qtr qtr0\n')
            qtr1 = self.get_cmd('hbaget hba_qtr qtr1\n')
            print "qtr val: %d %d" % (int(qtr0,16), int(qtr1,16))
            time.sleep(0.2)
            end = time.time()
            run_time = end - start

    def quad_test(self, seconds):
        self.set_cmd('hbaset hba_quad ctrl 3\n')
        start = time.time()
        end = time.time()
        run_time = end - start
        while run_time < seconds:
            enc = self.get_cmd('hbaget hba_quad enc\n')
            print "enc val: ",enc
            time.sleep(0.2)
            end = time.time()
            run_time = end - start


    def motor_test(self):
        print "setting motor speed to 10"
        self.set_cmd('hbaset hba_motor motor0 10\n')
        self.set_cmd('hbaset hba_motor motor1 10\n')

        print "Forward"
        self.set_cmd('hbaset hba_motor mode ff\n')
        self.quad_test(5)
        self.motor_stop()

        print "Reverse"
        self.set_cmd('hbaset hba_motor mode rr\n')
        self.quad_test(5)
        self.motor_stop()

        print "Turn Left"
        self.set_cmd('hbaset hba_motor mode rf\n')
        self.quad_test(5)
        self.motor_stop()

        print "Turn Right"
        self.set_cmd('hbaset hba_motor mode fr\n')
        self.quad_test(5)
        self.motor_stop()

        print "Done motor test"


    def menu(self):
        done = False
        print
        print "Menu"
        print "---------"
        print "0 : Serial Port Info"
        print "1 : Basicio leds, button test"
        print "2 : QTR, reflective/edge sensor test"
        print "3 : Motors/Encoders test"
        print "4 : Sonars test"
        print "5 : Encoders test"
        print "6 : Quit"

        choice = input("Enter choice [0-6], ctrl-c to stop test: ")
        print

        if choice==0:
            self.serial_info()
        elif choice==2:
            self.qtr_test(10)
        elif choice==3:
            self.motor_test()
        elif choice==5:
            self.quad_test(10)
        elif choice==6:
            done = True

        return done


# Start running here at main
if __name__ == "__main__":

    # Connect to the hbadaemon
    try:
        sock_hba = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_hba.connect(('localhost', 8870))

        # Create Romi_Test object
        test = Romi_Test(sock_hba)

        done = False
        while not done:
            try:
                done = test.menu()

            except KeyboardInterrupt:
                # Show menu again when ctrl-c
                print
                print("ctrl-c interrupt")
                test.motor_stop()
                continue

    except socket.error:
        print("Couldn't connect to hbaserver")
        sys.exit()

    finally:
        print("Exit normal.")
        sock_hba.close()



