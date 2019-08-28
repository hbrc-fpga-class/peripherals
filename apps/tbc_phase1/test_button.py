#!/usr/bin/env python3
import socket
import sys
from Sensor_Hub import Sensor_Hub

def wait_button(hub):


def run(hub):



# Start running here at main
if __name__ == "__main__":

    # Connect to the hbadaemon
    try:
        sock_hba = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_hba.connect(('localhost', 8870))

        # Create Sensor_Hub object
        hub = Sensor_Hub(sock_hba)

        # Run the test
        run(hub)

    except KeyboardInterrupt:
        # Show menu again when ctrl-c
        sock_hba.close()
        print("ctrl-c interrupt")
        sys.exit()

    except socket.error:
        print("Couldn't connect to hbaserver")
        sys.exit()

    finally:
        sock_hba.close()
        print("Exit normal.")
