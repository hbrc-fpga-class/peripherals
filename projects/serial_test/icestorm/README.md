# Implementation serial_test

## Description

The Makefile in this directory builds the serial_test project.
It is built using the icestorm tools.
It targets the TinyFPGA BX which has a
ice40 lp8k device.

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          4 / 63
GBs          0 / 8
  GB_IOs     0 / 8
LCs          551 / 7680
  DFF        257
  CARRY      69
  CARRY, DFF 31
  DFF PASS   120
  CARRY PASS 17
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 1
```

```
Number of cells:                776
     SB_CARRY                       92
     SB_DFF                          8
     SB_DFFE                         9
     SB_DFFER                       22
     SB_DFFES                        6
     SB_DFFESR                     165
     SB_DFFR                        63
     SB_DFFSR                       15
     SB_LUT4                       395
     SB_PLL40_CORE                   1
```
