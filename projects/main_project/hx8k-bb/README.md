# Implementation hba_system hx8k-bb

## Description

The Makefile in this directory builds the hba_system project.
It is built using the icestorm tools.
It targets the ice40-hx8k breakout board.

## Timing Estimate

Timing estimate: 10.57 ns (94.60 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          22 / 206
GBs          0 / 8
  GB_IOs     0 / 8
LCs          1034 / 7680
  DFF        513
  CARRY      120
  CARRY, DFF 37
  DFF PASS   220
  CARRY PASS 17
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 2
```

```
Number of cells:               1476
     SB_CARRY                      146
     SB_DFF                         20
     SB_DFFE                        29
     SB_DFFER                       22
     SB_DFFES                        6
     SB_DFFESR                     256
     SB_DFFR                        71
     SB_DFFSR                      146
     SB_IO                           4
     SB_LUT4                       775
     SB_PLL40_CORE                   1
```

