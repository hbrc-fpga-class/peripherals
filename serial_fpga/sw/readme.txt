============================================================

serial-fpga
The serial-fpga plug-in provides access to FPGA based
peripherals through a serial port.  A GPIO pin is used
to sense a service request from the FPGA.
  This plug-in opens the serial port and sets up the
GPIO pin.  It then verifies that the FPGA is responding.
Other plug-in modules communicate with this plug-in
using this plug-in's 'tx_pkt()' routine.  Each plug-in
that manages an FPGA peripheral must offer a 'rx_pkt'
routine.  See the source for gpio4.so for an example.



RESOURCES
port : The full path to the Linux serial port device.
Changing this causes the old device to be closed and
the new one opened.  The default value of 'device' is
/dev/ttyS0.

config : The serial port baud rate.  Valid values are
in the range of 1200 to 921600.  The port is always
configured to use RTS/CTS and 8n1.

intrr_pin : Which GPIO pin to use to sense service
requests from the FPGA.  Changing this value causes
the old pin to be unconfigured and the new pin to be
configured as an input using poll() on the pin's
/sys/class/gpio/gpioXX/value.  A 250 ms timer polls
the GPIO pin as a way to avoid missed interrupts.

rawin : Hexadecimal values to send directly to the
FPGA.  Use this resource to help debug your FPGA
peripheral.  This resource is write-only and has a
limit of 16 space separated hex values.

rawout : Hexadecimal values received on the serial
port.  Use hbacat to start a trace of received data.
This resource is read-only.


EXAMPLES
Use ttyS2 at 9600 baud.  Use GPIO pin 14 for interrupts
from the FPGA.  Start monitoring data from the FPGA and
send the command sequence b0 00 12 34 56.

 hbaset serial_fpga config 9600
 hbaset serial_fpga port /dev/ttyS2
 hbaset serial_fpga intrr_pin 14
 hbacat serial_fpga rawin &
 hbaset serial_fpga rawout b0 00 12 34 56


