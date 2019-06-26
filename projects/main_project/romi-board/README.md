# Implementation hba_system romi-board

## Status

In Development.

Current Peripheral list:

| Slot |    Peripheral   |
| ---- |:---------------:|
|   0  |    serial_fpga  |
|   1  |    hba_basicio  |
|   2  |    hba_qtr      |
|   3  |    hba_motor    |
|   4  |    hba_sonar    |


## Description

The Makefile in this directory builds the hba_system project.
It is built using the icestorm tools.
It targets the TinyFPGA breakout board.

## Timing Estimate

Timing estimate: 15.47 ns (64.64 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          29 / 63
GBs          0 / 8
  GB_IOs     0 / 8
LCs          1626 / 7680
  DFF        733
  CARRY      264
  CARRY, DFF 33
  DFF PASS   253
  CARRY PASS 36
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 1
```

