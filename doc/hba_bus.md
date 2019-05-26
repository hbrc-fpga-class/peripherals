# HomeBrew Automation Bus

## Description

This document describes the HomeBrew Automation (HBA) Bus.
This bus is used to interconnect FPGA peripherals together.

## HBA Bus Slave interface

An FPGA slave peripheral needs to implement the below
bus interface.  The bus signals are prefixed with __hba__.  
Signal with the postfix __slave__ are driven
by the slave HBA peripheral. Signals with the postfix __master__
are driven by a master HBA peripheral. 
The labels __input__ or __output__ are from
the perspective of the peripheral.
* __hba_clk (input)__ : This is the bus clock.  The HBA Bus signals are valid on the
  rising edge of this clock. 
* __hba_reset (input)__ : This signal indicates the peripheral should be reset.
* __hba_rnw (input)__ : 1=Read from register. 0=Write to register.
* __hba_select (input)__ : Indicates a transfer in progress.
* __hba_abus[11:0] (input)__ : The address bus.
    * __bits[11:8]__ : These 4 bits are the peripheral address. Max number of
      peripherals 16.
    * __bits[7:0]__ : These 8 bits are the register address. Max 256 reg per
      peripheral.
* __hba_dbus[7:0] (input)__ : Data sent to the slave peripherals.
* __hba_xferack_slave (output)__ : Acknowledge transfer requested.  Asserted when request has been
  completed. Must be zero when inactive.
* __hba_dbus_slave[7:0] (output)__ : Data from the slave.  Must be zero when inactive.
* __hba_interrupt_slave (output)__ : Each slave has a dedicated signal back to
  a interrupt controller. Optional.

The outputs of the slaves are OR'd together, except for __SlaveX_Interrupt__.

## HBA Bus Master interface

A peripheral can be both a master and a slave.  To be a master it needs to implement
the following additional signals.
* __hba_mgrantX (input)__ : Master access has be granted. From arbiter.
* __hba_xferack (input)__ : Asserted when request has been completed. 
    __OR__ of all __hba_xferack_slave__ signals
* __hba_request_masterX (output)__ : Requests access to the bus. 
* __hba_abus_master[11:0] (output)__ : The target address. Must be zero when inactive.
* __hba_rnw_master (output)__ : 1=Read from register. 0=Write to register.
* __hba_dbus_master[7:0] (output)__ : The write data bus.
* __hba_select_master (output)__ : Indicates a transfer in progress.

Additional required signals that are also part of the Slave interface.
* __hba_clk (input)__ : This is the bus clock.  The HBA Bus signals are valid on the
  rising edge of this clock. 
* __hba_reset (input)__ : This signal indicates the peripheral should be reset.
* __hba_dbus[7:0] (input)__ : The __OR__'d read data bus.

If there are mutliple slaves then the ports with the postfix __slave__ need to
be __OR__'d together to create the version without the postfix.  For example
__hba_xferack__ is created from the __OR__ of all the __hba_xerfack_slave_ signals.

If there are multiple masters then the ports with the postfix __master__ need to
be __OR__'d together to create the bus with out the prefix.  For example 
__hba_abus__ is created from the __OR__ of all the __hba_abus_master__ signals.

__hba_dbus__ is created from the __OR__ of all the __hba_dbus_master__ and __hba_dbus_slave__
signals.  It is unique in both master and slave peripherals can put data on the data bus.

Each peripheral master gets dedicated __hba_mgrantX__ and __hba_request_masterX__
signals back to the HBA Bus Arbiter. The 'X' represents a unique number.

## Notes
* Update to support burst transactions.
* Perhaps we can replace the peripheral address with dedicate peripheral enable signal.

