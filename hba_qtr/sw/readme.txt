============================================================

HARDWARE

The hba_qtr provides an interface to two
QTR reflectance sensors from Pololu.
Each sensor returns an 8-bit value which represents
The time it took for the QTR output pin to go
low after being charged.  The higher the reflectance
the shorter the time for the pin to go low.  The resolution
of the 8-bit value is in 10us.  So max value of
255 gives a time of 2.55ms.

RESOURCES

ctrl : This get/set the control register.
    - Bit 0 : Enable QTRs (left and right)
    - Bit 1 : Enable interrupt.
    - Bit 2 : Interrupt Type, Period=0 or Threshold=1
    - Bit 3 : Enable estop for cliff detection (0xff value)

This resource works with hbaget and hbaset.
The startup value is 0, with everything disabled.
Example values:
    - 1  : Enable reading QTRs
    - 3  : Enable reading QTRs and enable interrupts
    - f : Enbale QTRs, threshold interrupt, and estop

qtr : Reads left and right qtr values.
This resource works with hbaget and hbacat.
returns two 4 digit hex numbers: <left_qtr> <right_qtr>

period: Sets the trigger period. Granularity 50ms.
Default/Min 50ms.  time = (period*50ms)+50ms.

thresh: Value changes across this threshold cause an interrupt.
Interrupt type must be set to Threshold for this feature.
This resource works with hbaget and hbaset.

EXAMPLES
Set the trigger period to 100ms.
Enable both QTRs, and interrupt
Read back the last QTR values.
Cat the qtr values

 hbaset hba_qtr period 1
 hbaset hba_qtr ctrl 3
 hbaget hba_qtr qtr
 hbacat hba_qtr qtr

Set threshold to mid value 127dec = 0x1f
Enable both QTRs, threshold interrupt, cliff detection (estop)
Cat the qtr values

 hbaset hba_qtr thresh 1f
 hbaset hba_qtr ctrl f
 hbacat hba_qtr qtr

