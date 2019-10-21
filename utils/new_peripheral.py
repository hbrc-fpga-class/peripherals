#!/usr/bin/env python3

import sys
import yaml

#<------------------------------------------- 100 characters ------------------------------------->|

USAGE =  \
"""
Usage: new_peripheral.py [-h] [hba_periph.yaml]

This script generates template files for creating
a new HBA peripheral.  It generates a YAML, README.md,
verilog file, and a software driver in the sw directory.

When run with no arguments the script enters
interactive mode.  It asks a series of questions
before building the template files. A YAML file
with the peripheral data will be written when
the interfactive mode completes.

[hba_periph.yaml]: You can also specify a YAML file as an argument.
This will skip interactive mode and get the
required data from the YAML file.

[-h]: Prints out this usage information.
"""

class NewPeripheral:
    """
    This class is used to generate a new HBA peripheral
    """

    def __init__(self):
        self.pinfo = {}

    def save_yaml(self):
        mod_name = self.pinfo['name']

        with open(f"{mod_name}.yaml", 'w') as file:
            yaml.dump(self.pinfo, file, default_flow_style=False)

    def load_yaml(self, mod_name):
        with open(mod_name, 'r') as file:
            self.pinfo= yaml.safe_load(file)

    def prompt_pfino(self):
        # Prompt for some information about the module.
        self.pinfo['name'] = input("What is the name of your new peripheral? ")

        print("Give a multiline description (Ctrl-D when done): ")
        content = []
        while True:
            try:
                line=input()
            except EOFError:
                break
            content.append(line)
        self.pinfo['desc'] = '\n'.join(content)
        if input("Does it generate an interrupt(y or n)? ").lower() in ["y", "yes"]:
            self.pinfo['interrupt'] = True
        else:
            self.pinfo['interrupt'] = False
        num_reg = int(input("How many registers? "))
        self.pinfo['reg_info'] = []
        for i in range(num_reg):
            reg_name = input(f"  reg[{i}] name? ")
            reg_rw = ""
            while not reg_rw in ["r", "w", "rw"]:
                reg_rw = input(f"    Does this module (r)ead, (w)rite, or (rw)both {reg_name}? ")
                reg_rw = reg_rw.lower()
                reg_desc = input(f"    Describe/Document this register: ")
            self.pinfo['reg_info'].append(dict(name=reg_name, rw=reg_rw, desc=reg_desc))

    def write_module(self):
        mod_name = self.pinfo['name']
        mod_interrupt = self.pinfo['interrupt']

        module_txt = \
f"""// Force error when implicit net has no type.
`default_nettype none

module {mod_name} #
(
    // Defaults
    // DBUS_WIDTH = 8
    // ADDR_WIDTH = 12
    parameter integer DBUS_WIDTH = 8,
    parameter integer PERIPH_ADDR_WIDTH = 4,
    parameter integer REG_ADDR_WIDTH = 8,
    parameter integer ADDR_WIDTH = PERIPH_ADDR_WIDTH + REG_ADDR_WIDTH,
    parameter integer PERIPH_ADDR = 0
)
(
    // HBA Bus Slave Interface
    input wire hba_clk,
    input wire hba_reset,
    input wire hba_rnw,         // 1=Read from register. 0=Write to register.
    input wire hba_select,      // Transfer in progress.
    input wire [ADDR_WIDTH-1:0] hba_abus, // The input address bus.
    input wire [DBUS_WIDTH-1:0] hba_dbus,  // The input data bus.

    output wire [DBUS_WIDTH-1:0] hba_dbus_slave,   // The output data bus.
    output wire hba_xferack_slave,     // Acknowledge transfer requested. 
                                    // Asserted when request has been completed. 
                                    // Must be zero when inactive.
    output {'reg' if mod_interrupt else 'wire' } slave_interrupt,   // Send interrupt back

    // hba_basicio pins
    output wire [7:0] basicio_led,
    input wire [7:0] basicio_button
);
"""
        with open(f"{mod_name}.v", "w") as vfile:
            vfile.write(module_txt)

    def write_readme(self):
        mod_name = self.pinfo['name']
        mod_desc = self.pinfo['desc']
        readme_txt = \
f"""# {mod_name}

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
{mod_desc}

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __slave_interrupt__ (output) : Asserted when button state changes and the
  interrupt is enabled.
* __basicio_led[7:0]__ (output) : The 8-bit led port.
* __basicio_button[7:0]__ (input) : The 2-bit button port.

## Register Interface

There are three 8-bit registers.

"""

        i = 0
        for reg_info in self.pinfo['reg_info']:
            line = f"* __reg{i}__({reg_info['rw']}) : ({reg_info['name']}) - {reg_info['desc']}"
            readme_txt += line + "\n"
            i += 1

        with open(f"README.md", "w") as mdfile:
            mdfile.write(readme_txt)

# Start running here
if __name__ == "__main__":

    # Check the python version.  We need 3.6 to support f-strings.
    MIN_PYTHON = (3, 6)
    if sys.version_info < MIN_PYTHON:
        print("Python %s.%s or later is required." % MIN_PYTHON)
        print(sys.version_info)
        sys.exit()

    # Create the new peripheral object
    new_periph = NewPeripheral()

    # Handle arguments
    if len(sys.argv) == 1:
        # Interactive mode if no arguments
        new_periph.prompt_pfino()
        new_periph.save_yaml()
    elif len(sys.argv) == 2:
        # Only one argument.
        # See if it is the -h option
        if sys.argv[1] in ["-h", "-help", "--help"]:
            print(USAGE)
            sys.exit()
        # See if we can load the YAML file
        try:
            new_periph.load_yaml(sys.argv[1])
        except Exception as e:
            print("ERROR: " + str(e))
            print("Can't open YAML file: ",sys.argv[1])
            sys.exit()
    else:
        # Too many arguments
        print(USAGE)
        sys.exit()

    new_periph.write_readme()
    new_periph.write_module()


