# hba_gpio

## Description

This module is a HBA (HomeBrew Automation) bus peripheral.
It provides an interface to control 4 GPIO pins.

Inputs on the GPIO port are configured with internal
weak pullups.  So if not actively being driven they
will read back as logical 1 values.

## Port Interface

This module implements an HBA Slave interface.
It also has the following additional ports.

* __slave_interrupt__ : Asserted when an input pin changes state
and the interrupt is enabled in the reg_intr_en register.
* __gpio_out_en[3:0]__ : Tri-state control pin. When 1, the associated
pin is an output, else it is an input.
* __gpio_out_sig[3:0]__ : The signal to drive the pin.
* __gpio_in_sig[3:0]__ : The input signal from the pin.

## Register Interface

There are three 8-bit registers. Since the module only controls 4 GPIOs
only the lower 4-bit of each register is active.

* __reg0__: Direction Register(reg_dir) (a.k.a out_en) . This register
  specifies each pin as an input or an output.  1=output, 0=input.
* __reg1__: Pins Register(reg_pins).  This register is used to read or
  write the value of the pins.
* __reg2__: Interrupt Register(reg_intr_en).  This register is an
  interrupt enable mask.  A value of 1 on a bit indicates the interrupt
  is enabled for that pin.

## Example

Assume that hba_gpio is at peripheral address 1 (slot1).
The the following command uses the "raw" bytes interface to set
* reg0 = 0x0F   // reg_dir, all gpios are outputs
* reg1 = 0x02   // reg_pins, gpio outputs 0x02
* reg2 = 0x00   // reg_inter_en, all interrupts are disabled.

```
hbaset serial_fpga rawout 21 00 0F 02 00 FF
# Returned byte
# ac
```

Reading the three registers.

```
hbaset serial_fpga rawout a1 00 FF FF FF FF FF
# Returned bytes
# a0 00 0f 02 00
```

We can see from the last three returned bytes that 
that the registers have the values we expect.

Now lets change reg0[0] to 0, to make the lsb pin and input.
* reg0 = 0x0e

```
hbaset serial_fpga rawout 01 00 0e FF
# Returned byte
# ac
```

Now lets read back all three values again:

```
hbaset serial_fpga rawout a1 00 FF FF FF FF FF
# Returned bytes
# a0 00 0e 03 00
```

We can see that reg1 as changed form 0x02 to 0x03 because
the lsb pin is set as an input that has a pull up on it.



