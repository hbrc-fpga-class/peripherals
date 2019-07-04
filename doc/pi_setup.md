# Pi Setup Notes

## Raspberry Pi Image

We are using a customized version of the Ubiquity Robotics Pi image.
It can be downloaded from:

[https://ubiquity-pi-image.sfo2.cdn.digitaloceanspaces.com/2019-06-18-hbrc-fpga-rpi.img.xz](https://ubiquity-pi-image.sfo2.cdn.digitaloceanspaces.com/2019-06-18-hbrc-fpga-rpi.img.xz)

You can use GNOME Disk Tool to flash the image onto a 16GB Micro SD card.
Instructions are similar to the [Ubiquity instructions](https://downloads.ubiquityrobotics.com/pi.html).

## Connect to Wifi and change hostname

When you power on the Pi it creates it's own wifi AP.  I'm not sure the exact name but
is is something like "homebrewXXX".  You can connect to that AP via another computer
and ssh into the Pi via.

```
ssh ubuntu@hombrew.local
```

The password is "ubuntu"

Alternatively you can hookup a HDMI monitor, keyboard and mouse and login through the
GUI.

Once you get to a terminal you can use the "pifi" program to connect to another wifi
network.

```
pifi add <ssid> [<password>]
```

You can also use pifi to change the hostname to something unique. For example I did:

```
pifi set-hostname hbrc2
```

Now reboot.

## SSH in from remote computer

Now that the Pi connects to a local netowrk and has a unqiue name you can
login into it from a remote machine.  You no longer need keyboard, mouse, and monitor
attached to the Raspberry Pi.

From remote computer that is connected to the same WiFi network as the Pi:

```
ssh ubuntu@hbrc2.local
```

Password is "ubuntu"

## Raspberri Pi GPIO connections to TinyFPGA board

[Raspberry Pi 3 B+ pinout reference](https://pi4j.com/1.2/pins/model-3b-plus-rev1.html)

[TinyFPGA-BX pinout](https://www.crowdsupply.com/img/a1f0/card-front_png_project-body.jpg)

**NOTE** These connections are for the current version of main_project/romi-board
that is checked in to the master branch of peripherals.  This will change
in the future when the project is updated for the custom PCB board.

| Rasp Pi          | TinyFPGA           |
| ---------------- | ------------------:|
| Pi_txd (GPIO15)  | FPGA_rxd (PIN_23)  |
| Pi_rxd (GPIO16)  | FPGA_txd (PIN_22)  |
| Pi_intr (GPIO25) | FPGA_intr (PIN_24) |
| Pi_gnd (pin 39)  | TinyFPGA GND       |


## Clone eedd and peripherals repository

From the home directory

```
mkdir hbrc_fpga_class
cd hbrc_fpga_class
git clone --depth=1 https://github.com/hbrc-fpga-class/peripherals.git
git clone --depth=1 -b hba https://github.com/bob-linuxtoys/eedd.git
cd eedd
make
sudo make install
```

## To program the TinyFPGA

```
cd ~/hbrc_fpga_class/peripherals/projects/main_project/romi-board/
make
make prog
```

## Test Communication

From one terminal logged in to the pi.

```
hbadaemon -ef
```

From a second terminal logged in to the pi.

```
hbaset 0 port /dev/ttyAMA0
hbaset 1 leds 1
hbaset 1 leds 0
```

You should see the user led on the TinyFPGA-BX board turn on
then off.



