# The HBA Romi Adapter Board RPi HAT EEPROM

## Release Notes

12/2019

This update to the HAT's configuration EEPROM adds automatic configuration of the RPi's hardware via the EEPROM's device-tree overlay.

The HAT EEPROM's updated device-tree overlay automatically configures the RPi's hardware to support the Serial FPGA UART and SPI Flash, without having to edit the kernel's boot configuration. When plugged into a new RPi, the board just works.

The updated HAT EEPROM image also includes a few handy HAT data files.  These files include a list of the configured FPGA peripherals/slots for enumeration, and source code for the HAT's own device-tree overlay for troubleshooting.

## Reprogramming your HBA Romi Board HAT EEPROM

The file 'romi-board.eep' in this directory is ready to be uploaded to your HBA Romi Board.

No other software tools are required, but you will need to short the board's Write Protect jumper (J6).

If you like, you can solder header pins to J6 and add a jumper when you want to reprogram the EEPROM.  However, the easiest method is to simply poke a pair of metal tweezers into the empty pads of J6, thereby shorting the Write Protect signal to ground.

* sudo make prog

Remove the jumper from J6 and reboot the RPi, to restart the kernel with the updated device-tree and HAT configuration.

## Building new RPi HAT EEPROM Images

#### EEPMake is required to format EEPROM images from I/O settings, device-tree blob overlays, and custom user data files...

* git clone https://github.com/raspberrypi/hats.git
* cd ./hat/eepromutils/
* make

## Building the Device-Tree Overlay

#### DTC is required to compile Device-Tree Source files into Device-Tree Blob Overlays...

* git clone https://git.kernel.org/pub/scm/linux/kernel/git/jdl/dtc.git
* cd ./dtc
* make
* sudo make install

## The SPI-NOR Device Driver and the TinyFPGA BX Flash Device

The utilities 'tinyprog' and 'prog_fpga.py' continue to function as before, to write your designs to the FPGA and Flash memory.

The file 'romi-board-flash-overlay.dts' represents my aborted efforts to get direct access to the TinyFPGA's program flash memory from Linux.

Although other JEDEC SPI-NOR flash devices like the TinyFPGA's 'at25df081a' chip are supported by the Linux Kernel (including its 4Mb sister device), I've not been able to find a generic device-tree configuration that will work with the TinyFPGA.  Please use this overlay file as the starting point for your own experimentation.  Success may require adding configuration specifics for this device to the SPI-NOR kernel driver code.

## Notes

The Romi Adapter Board connects via these devices...

### SPI Flash (JEDEC Compatible) in the TinyFPGA...

*  https://github.com/tinyfpga/TinyFPGA-BX/blob/master/board/TinyFPGA-BX-Schematic.pdf
*  https://www.adestotech.com/wp-content/uploads/doc8715.pdf
*  http://www.linux-mtd.infradead.org/doc/general.html
*  https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/mtd/jedec%2Cspi-nor.txt

### Romi Power Circuit...

*  https://www.pololu.com/file/0J1213/motor-driver-and-power-distribution-board-for-romi-chassis-schematic.pdf

### Romi Adapter Board Button...

*  https://github.com/hbrc-fpga-class/hardware/blob/rev-A/tinyfpga-raspi-romi-board/outputs/tinyfpga-raspi-romi-board.pdf
