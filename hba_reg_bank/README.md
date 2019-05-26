# hba_reg_bank

## Description

This module implements a register bank that can
be accessed over the HBA (HomeBrew Automation) bus.
It is common that this module is instantiated insided
a HBA slave peripheral.

The current implementation only supports 4 registers.

## Interface

Besides the HBA Bus Slave interface there are additional ports:

* __slv_regX__ : These ports expose the current register values
to the enclosing module.
* __slv_regX_in__ : These port allow you to write to the __slv_regX__
register from the enclosing module.
* __slv_wr_mask__ : Indicates which __slv_regX__ are writable from
the enclosing module.
* __slv_wr_en__ : When asserted the __slv_regX_in__ values are copied
to the corresponding __slv_regX__ registers if they are enabled for
writing in the __slv_wr_mask__
* __slv_autoclr_mask__ : Indicates which __slv_regX__ should be auto-cleared
when read from the host interface.


## ToDo

* Make the number of registers a parameter.

