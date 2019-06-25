# hba_sonar

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It provides an interface to control two SR04 sonars.
It also has a trigger sync input, and registers for
specifying offsets from the trigger sync.  This way
if there are multiple sonar peripherals the triggers can
be staggered so they don't all fire at the same time and
cause a large current draw.

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __slave_interrupt__ (output) : Asserted when a new sonar value(s) are available.
* __sonar_trig[1:0]__ (output) : The trigger signals for the two sonars.
* __sonar_echo[1:0]__ (input) : The return echo.


## Register Interface

There are four 8-bit registers.

* __reg0__ : Control register. Enables sonars and interrupts.
    * reg0[0] : Enable sonar 0.
    * reg0[1] : Enable sonar 1.
* __reg1__ : Last Sonar0 value
* __reg2__ : Last Sonar1 value
* __reg3__ : Trigger period.  Granularity 50ms. Default 100ms.


## TODO

Add support for the following ports:

* __sonar_sync_in__ (input) : Synchronization input pulse for multiple sonar peripherals.
Used to stagger trigger, so they don't all trigger at the same time.
* __sonar_sync_out__ (output) : The master sync pulse.  One of the sonar peripherals
will be be the master.

Add support for the following bits and registers:

* __reg0__ : Control register. Enables sonars and interrupts.
    * reg0[2] : Slave sync.  If 1 use the sonar_sync_in for trigger.
Default(0) generate internal sync pulse.
    * reg0[3] : Enable sonar interrupt. Triggered once per cycle.
    * reg0[7:4] : Unused
* __reg4__ : Time slice for sonar 0 trigger after sync. Granularity 1ms.
* __reg5__ : Time slice for sonar 1 trigger after sync. Granularity 1ms.


