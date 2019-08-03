# Pi Setup Notes

## Raspberry Pi Image

We are using a customized version of the Ubiquity Robotics Pi image.
The latest FPGA HBRC class image can be downloaded from this page.

[https://downloads.ubiquityrobotics.com/hbrc-fpga-class.html](https://downloads.ubiquityrobotics.com/hbrc-fpga-class.html)


## Setup Wifi

When you power on the Pi it creates it's own wifi AP.  The AP name will be
something like "homebrewXXXX", where XXXX is the last 4 digits of the MAC address.
You can connect to that AP via another computer
and ssh into the Pi via.  The AP passkey should be *robotseverywhere*

```
ssh ubuntu@homebrew.local
```

The password is "ubuntu"

Alternatively you can hookup a HDMI monitor, keyboard and mouse and login through the
GUI.

Once you get to a terminal you can use the "pifi" program to connect to another wifi
network.

```
sudo pifi add <ssid> [<password>]
```

For the HBRC class we will have a Wifi network setup. It will have a dual band
configuration, one for 5Ghz (Homebrew5), and one for 2.4Ghz (Homebrew2.4).  

Here is the SSID information
1. 5Ghz (preferred) : SSID: Homebrew5 , password: ilikerobots
2. 2.4Ghz : SSID : Homebrew2.4 , password: ilikerobots

We want the Pi's to connect to Homebrew5 for it should have more bandwidth.
Add the Homebrew5 wifi network using pifi:

```
sudo pifi add Homebrew5 ilikerobots
```

You can add additional wifi networks like your home wifi network.

## Change hostname

Each class Raspberry Pi has a label with "HXX" on the back.
The "XX" is a two digit number.  So far the labels go from "H01" to "H23".
If you are using your own Pi, and don't have a label contact the
class leaders to get assigned a number.  The goal is for every Pi
in the class to have a unique hostname.

We need to update the hostname of the Pi
to match the label.  We can use pifi to update the hostname.

For example if your label was "H01", type:

```
sudo pifi set-hostname H01
```

Now reboot.

```
sudo reboot
```

## SSH in from remote computer

Now that the Pi connects to a local netowrk and has a unqiue name you can
login into it from a remote machine.  You no longer need keyboard, mouse, and monitor
attached to the Raspberry Pi.

From remote computer that is connected to the same WiFi network as the Pi:

```
ssh ubuntu@H01.local
```

Password is "ubuntu"

## Change to Command Line Interface (CLI)

To save power change from the X Desktop interface to the Command Line Interface.

```
sudo raspi-config
```

Select the following:
* 2 Boot Options
* B1 Desktop/CLI
* B1 Console Text console
* Finish
* Reboot

## Install "expect"

[Expect](https://likegeeks.com/expect-command/) command or expect scripting language is a language 
that talks with your interactive programs or scripts that require user interaction.

```
sudo apt-get update && sudo apt-get install expect
```



## Update eedd and peripherals repository

From the home directory

```
cd ~/hbrc_fpga_class/peripherals
git pull origin master
cd ../eedd
git pull origin hba
make
sudo make install
```

## Create hbadaemon.service

The hbadaemon is what communicates with the FPGA peripherals over a serial connection.
It is a daemon that can run in the background.  We can start it automatically by creating
a file **/etc/systemd/system/hbadaemon.service** with the following content:

```
[Unit]
Description=HBA control program for FPGA based hardware
After=NetworkManager.service

[Service]
Type=forking
User=ubuntu
ExecStart=/usr/local/bin/hbadaemon

[Install]
WantedBy=multi-user.target
```

Then run

```
sudo systemctl daemon-reload && sudo systemctl enable hbadaemon.service
```

Then reboot


## To program the TinyFPGA

The class TinyFPGA have already been programmed with a default bitstream.
To load a new bitstream follow the instructions below.

```
cd ~/hbrc_fpga_class/peripherals/projects/main_project/romi-pcb/
make
make prog
```

## Update bashrc

In the peripherals repository there a bash script called **setup.bash**.
The script adds the peripherals/utils directory to the PATH env var.
The utils directory contains the python script prog_fpga.py that
programs the FPGA over the Pi's SPI pins.  Source this setup.bash
from the .bashrc file in the home directory.  This is done
by adding the following to the end of the /home/ubuntu/.bashrc
script.

```
# HBA setup
source ${HOME}/hbrc_fpga_class/peripherals/setup.bash
```


Logout then log back in to activate the .bashrc.


## Test Communication

After boot, press the button on the FPGA to load the FPGA bitstream.

From a terminal logged in to the pi.

```
hbaset 1 leds 1
hbaset 1 leds 0
```

You should see the user led on the TinyFPGA-BX board turn on
then off.

## Test of all the Peripherals

There is a python program in apps/romi_test/romi_test.py that provides
a menu to test all the different peripherals. This should work with the
main_project bitstreams.

The menu looks like this

```
Menu
---------
0 : Serial Port Info
1 : Basicio leds, button test
2 : QTR, reflective/edge sensor test
3 : Motors/Encoders test
4 : Sonars test
5 : Encoders test
6 : Quit
Enter choice [0-6], ctrl-c to stop test:
```

Running test 3 : Motors/Encoders test gives output like this..

```
Enter choice [0-6], ctrl-c to stop test: 3

setting motor speed to 10
Forward
enc val: 0 0
enc val: 111 116
enc val: 223 232
enc val: 335 349
enc val: 448 466
enc val: 562 584
enc val: 676 702
enc val: 791 821
enc val: 906 939
enc val: 1020 1057
```

