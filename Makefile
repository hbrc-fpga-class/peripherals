#
#  Name: Makefile
#
#  Description: This is the top level Makefile for the plug-ins
#
#  Copyright:   Copyright (C) 2019 by Demand Peripherals, Inc.
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

plugins:
	make EE_DIR=$(EE_DIR) -C hba_basicio/sw all
	make EE_DIR=$(EE_DIR) -C hba_gpio/sw all
	make EE_DIR=$(EE_DIR) -C hba_sonar/sw all
	make EE_DIR=$(EE_DIR) -C serial_fpga/sw all

clean:
	make EE_DIR=$(EE_DIR) -C hba_basicio/sw clean
	make EE_DIR=$(EE_DIR) -C hba_gpio/sw clean
	make EE_DIR=$(EE_DIR) -C hba_sonar/sw clean
	make EE_DIR=$(EE_DIR) -C serial_fpga/sw clean

plugins-install:
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_basicio/sw install
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_gpio/sw install
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_sonar/sw install
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C serial_fpga/sw install

plugins-uninstall:
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_basicio/sw uninstall
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_gpio/sw uninstall
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C hba_sonar/sw uninstall
	make INST_LIB_DIR=$(INST_LIB_DIR) EE_DIR=$(EE_DIR) -C serial_fpga/sw uninstall

.PHONY : clean install uninstall

