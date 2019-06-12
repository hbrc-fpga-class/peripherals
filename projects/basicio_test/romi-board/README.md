# Implementation sonar_test

## Description

The Makefile in this directory builds the sonar_test project.
It is built using the icestorm tools.
It targets the TinyFPGA BX which has a
ice40 lp8k device.

## Timing Estimate

Timing estimate: 13.27 ns (75.36 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          9 / 63
GBs          0 / 8
  GB_IOs     0 / 8
LCs          820 / 7680
  DFF        390
  CARRY      118
  CARRY, DFF 33
  DFF PASS   159
  CARRY PASS 18
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 1
```

```
Number of cells:               1185
     SB_CARRY                      140
     SB_DFF                         12
     SB_DFFE                        28
     SB_DFFER                       23
     SB_DFFES                        6
     SB_DFFESR                     209
     SB_DFFR                        64
     SB_DFFSR                       81
     SB_LUT4                       621
     SB_PLL40_CORE                   1
```
