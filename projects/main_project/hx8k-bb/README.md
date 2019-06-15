# Implementation hba_system hx8k-bb

## Description

The Makefile in this directory builds the hba_system project.
It is built using the icestorm tools.
It targets the ice40-hx8k breakout board.

## Timing Estimate

Timing estimate: 9.98 ns (100.18 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          18 / 206
GBs          0 / 8
  GB_IOs     0 / 8
LCs          922 / 7680
  DFF        446
  CARRY      120
  CARRY, DFF 37
  DFF PASS   183
  CARRY PASS 17
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 2
```

```
Number of cells:               1330
     SB_CARRY                      146
     SB_DFF                         16
     SB_DFFE                        29
     SB_DFFER                       22
     SB_DFFES                        6
     SB_DFFESR                     232
     SB_DFFR                        71
     SB_DFFSR                      107
     SB_LUT4                       700
     SB_PLL40_CORE                   1
```

