#
#  Name: Makefile
#
#  Description: Makefile for building and installing the RPi Hat EEPROM.
#
#  Copyright:   Copyright (C) 2019 by AGM
#               All rights reserved.
#
#  License:     This program is free software; you can redistribute it and/or
#               modify it under the terms of the Version 2 of the GNU General
#               Public License as published by the Free Software Foundation.
#               GPL2.txt in the top level directory is a copy of this license.
#               This program is distributed in the hope that it will be useful,
#               but WITHOUT ANY WARRANTY; without even the implied warranty of
#               MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#               GNU General Public License for more details.
#
EEPPATH=~/git/hats/eepromutils/

all: romi-board.eep
	@echo
	@echo '  Use "sudo make prog" to update the RPi Hat EEPROM.'
	@echo

test:
	@echo
	dtc -@ -I dts -O dtb romi-board.dts | dtc -I dtb -O dts -
	@echo

verify:
	@echo
	@ls -la /sys/firmware/devicetree/base/hat/*
	@echo
	@ls -la /dev/serial[0-9]
	@echo
	@ls -la /dev/spi*[0-9]
	@echo
	@ls -lad /sys/firmware/devicetree/base/soc/gpio@*/fpga*
	@ls -lad /sys/firmware/devicetree/base/soc/gpio@*/romi*
	@echo
	-@raspi-gpio get | egrep 'GPIO 0?[2356]:|GPIO 13:|GPIO 25:'
	@echo

romi-board.dtbo: romi-board.dts
	dtc -@ -I dts -O dtb -o $@ $?

romi-board.eep: romi-board.settings romi-board.dtbo Peripherals.txt romi-board.dts
	${EEPPATH}eepmake romi-board.settings $@ romi-board.dtbo -c Peripherals.txt romi-board.dts

prog: romi-board.eep | /sys/class/i2c-adapter/i2c-3/3-0050/eeprom
	dd obs=256 if=$? of=/sys/class/i2c-adapter/i2c-3/3-0050/eeprom

/sys/class/i2c-adapter/i2c-3/3-0050/eeprom: | /sys/class/i2c-adapter/i2c-3/new_device
	modprobe at24
	echo '24c32 0x50' >> /sys/class/i2c-adapter/i2c-3/new_device

/sys/class/i2c-adapter/i2c-3/new_device:
	modprobe i2c-gpio
	dtoverlay i2c-gpio i2c_gpio_sda=0 i2c_gpio_scl=1 bus=3

clean:
	rm -f romi-board.dtbo romi-board.eep

.PHONY: all test prog verify clean
