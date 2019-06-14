char README[] = "\
============================================================\n\
\n\
HARDWARE\n\
\n\
The hba_sonar peripheral provides an interface to control two\n\
SR04 sonars.  There is a control register that can be used\n\
to enable each sonar independently. There is a sonar0_val\n\
register and a sonar1_val register that reads the last\n\
recorded sonar values.\n\
\n\
This peripheral generates an interrupt when the sonar(s) fire.\n\
In the future there will be a register to disable the interrupt.\n\
\n\
RESOURCES\n\
\n\
ctrl : This get/set the control register.  Here are the \n\
currently support values:\n\
    - 0 : Disable both sonars\n\
    - 1 : Enable Sonar 0.\n\
    - 2 : Enable Sonar 1.\n\
    - 3 : Enable both Sonar0 and Sonar1.\n\
This resource works with hbaget and hbaset.\n\
\n\
sonar0 : Reads the last sonar0 value.\n\
This resource works with hbaget and hbacat.\n\
\n\
sonar1 : Reads the last sonar1 value.\n\
This resource works with hbaget and hbacat.\n\
\n\
\n\
EXAMPLES\n\
Enable only Sonar 0.\n\
Read back the value of Sonar 0.\n\
Echo back new sonar 0 values.\n\
\n\
 hbaset hba_sonar ctrl 1\n\
 hbaset hba_sonar sonar0\n\
 hbacat hba_sonar sonar0\n\
\n\
";
