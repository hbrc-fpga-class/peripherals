# Implementation sonar_test hx8k-bb

## Description

The Makefile in this directory builds the sonar_test project.
It is built using the icestorm tools.
It targets the ice40-hx8k breakout board.

## Timing Estimate

Timing estimate: 9.98 ns (100.18 MHz)

## Utilization

Here are the utilization numbers:

```
After packing:
IOs          8 / 206
GBs          0 / 8
  GB_IOs     0 / 8
LCs          826 / 7680
  DFF        392
  CARRY      120
  CARRY, DFF 37
  DFF PASS   159
  CARRY PASS 17
BRAMs        0 / 32
WARMBOOTs    0 / 1
PLLs         1 / 2
```

```
Number of cells:               1204
     SB_CARRY                      146
     SB_DFF                         12
     SB_DFFE                        28
     SB_DFFER                       22
     SB_DFFES                        6
     SB_DFFESR                     209
     SB_DFFR                        71
     SB_DFFSR                       81
     SB_LUT4                       628
     SB_PLL40_CORE                   1
```


