============================================================

HARDWARE

This module is a HBA (HomeBrew Automation) bus peripheral.
It enables a simple speed controller.

RESOURCES

lspeed : The left desired speed.
This resource works with hbaget and hbaset.

rspeed : The right desired speed.
This resource works with hbaget and hbaset.

actual : The actual left and right speed
This resource works with hbaget and hbacat.

EXAMPLES

Set the desired lspeed to 10.
Set the desired rspeed to 10.
Cat the actual speed.

 hbaset hba_speed_lspeed 10
 hbaset hba_speed_rspeed 10
 hbacat hba_speed_actual


