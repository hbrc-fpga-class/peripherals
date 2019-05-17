char README[] = "\
============================================================\n\
\n\
serial-fpga\n\
The serial-fpga plug-in provides access to FPGA based\n\
peripherals through a serial port.  A GPIO pin is used\n\
to sense a service request from the FPGA.\n\
  This plug-in opens the serial port and sets up the\n\
GPIO pin.  It then verifies that the FPGA is responding.\n\
Other plug-in modules communicate with this plug-in\n\
using this plug-in's 'tx_pkt()' routine.  Each plug-in\n\
that manages an FPGA peripheral must offer a 'rx_pkt'\n\
routine.  See the source for gpio4.so for an example.\n\
\n\
\n\
\n\
RESOURCES\n\
port : The full path to the Linux serial port device.\n\
Changing this causes the old device to be closed and\n\
the new one opened.  The default value of 'device' is\n\
/dev/ttyS0.\n\
\n\
config : The serial port baud rate.  Valid values are\n\
in the range of 1200 to 921600.  The port is always\n\
configured to use RTS/CTS and 8n1.\n\
\n\
intrr_pin : Which GPIO pin to use to sense service\n\
requests from the FPGA.  Changing this value causes\n\
the old pin to be unconfigured and the new pin to be\n\
configured as an input using poll() on the pin's\n\
/sys/class/gpio/gpioXX/value.  A 250 ms timer polls\n\
the GPIO pin as a way to avoid missed interrupts.\n\
\n\
rawin : Hexadecimal values to send directly to the\n\
FPGA.  Use this resource to help debug your FPGA\n\
peripheral.  This resource is write-only and has a\n\
limit of 16 space separated hex values.\n\
\n\
rawout : Hexadecimal values received on the serial\n\
port.  Use hbacat to start a trace of received data.\n\
This resource is read-only.\n\
\n\
\n\
EXAMPLES\n\
Use ttyS2 at 9600 baud.  Use GPIO pin 14 for interrupts\n\
from the FPGA.  Start monitoring data from the FPGA and\n\
send the command sequence b0 00 12 34 56.\n\
\n\
 hbaset serial-fpga config 9600\n\
 hbaset serial-fpga port /dev/ttyS2\n\
 hbaset serial-fpga intrr_pin 14\n\
 hbacat serial-fpga rawout &\n\
 hbaset serial-fpga rawin b0 00 12 34 56\n\
\n\
\n\
";
