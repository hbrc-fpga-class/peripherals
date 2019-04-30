# Home Brew Automation Bus

## Description

This document describes the Home Brew Automation (HBA) Bus.
This bus is used to interconnect FPGA peripherals together.

## HBA Bus Slave interface

An FPGA slave peripheral needs to implement the below
bus interface.  Signals with the  prefix __HBA__ are driven
by the bus master.  Signal with the prefix __Slave__ are driven
by the slave FPGA peripheral. The labels __input__ or __output__ are from
the perspective of the peripheral.
* __HBA_Clk (input)__ : This is the bus clock.  The HBA Bus signals are valid on the
  rising edge of this clock. 
* __HBA_Reset (input)__ : This signal indicates the peripheral should be reset.
* __HBA_RNW (input)__ : 1=Read from register. 0=Write to register.
* __HBA_ABus[11:0] (input)__ : The address bus.
    * __bits[11:8]__ : These 4 bits are the peripheral address. Max number of
      peripherals 16.
    * __bits[7:0]__ : These 8 bits are the register address. Max 256 reg per
      peripheral.
* __HBA_DBus[7:0] (input)__ : Data sent to the slave peripherals.
* __Slave_xferAck (output)__ : Acknowledge transfer requested.  Asserted when request has been
  completed. Must be zero when inactive.
* __Slave_DBus[7:0] (output)__ : Data from the slave.  Must be zero when inactive.
* __SlaveX_Interrupt (output)__ : Each slave has a dedicated signal back to
  a interrupt controller. Optional.

The outputs of the slaves are OR'd together, except for __SlaveX_Interrupt__.

## HBA Bus Master interface

A peripheral can be both a master and a slave.  To be a master it needs to implement
the following additional signals.
* __OPB_MXGrant (input)__ : Master access has be granted. 
* __OPB_xferAck (input)__ : Asserted when request has been completed.
* __MasterX_request (output)__ : Requests access to the bus. 
* __Master_ABus[11:0] (output)__ : The target address. Must be zero when inactive.

If there is more than one master then the the their __Master_ABus[11:0]__ are OR'd
together.

Each peripheral master gets dedicated __OPB_MXGrant__ and __OPB_MasterX_request__
signals back to the HBA Bus Arbiter. The 'X' represents a unique number.


