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
|   5  |    hba_quad     |


## Description

The Makefile in this directory builds the hba_system project.
It is built using the icestorm tools.
It targets the TinyFPGA breakout board.

## Timing Estimate

Timing estimate: 16.07 ns (62.23 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          33 / 63
GBs          0 / 8
  GB_IOs     0 / 8
LCs          2059 / 7680
  DFF        892
  CARRY      350
  CARRY, DFF 33
  DFF PASS   313
  CARRY PASS 70
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 1

```

