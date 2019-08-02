#!/usr/bin/python3

import RPi.GPIO as GPIO
import spidev
import sys

BUF_LEN = 500

extra_bytes = [0x00] * 49

# check the number of arguments
if len(sys.argv) != 2:
	print("Usage: prog_fpga.py top.bin")
	sys.exit()

bitfile = sys.argv[1]
print("bitfile: ", bitfile)

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
FPGA_SS = 8
GPIO.setup(FPGA_SS,GPIO.OUT)
GPIO.output(FPGA_SS,False)

print("Press the creset button on the TinyFPGA")
input("Then press enter")
GPIO.cleanup()

# We only have SPI bus 0 available to us on the Pi
bus = 0

#Device is the chip select pin. Set to 0 or 1, depending on the connections
device = 0

# Enable SPI
spi = spidev.SpiDev()

# Open a connection to a specific bus and device (chip select pin)
spi.open(bus, device)

# Set SPI speed and mode
#spi.max_speed_hz = 500000
spi.max_speed_hz = 10000000
spi.mode = 0


print("...programming")


# print some of the bitfile info
# Read file as binary using "rb"
i=0
with open(bitfile, mode="rb") as fp:
	while True:
		chunk = list(fp.read(BUF_LEN))
		if (not chunk):
			break

		spi.xfer2(chunk)

# Send the 49 extra bytes 
# Acutally only need 49 clocks
# but a little extra does not hurt.
spi.xfer2(extra_bytes)


print("Done")

# Close the spi bus
spi.close()





