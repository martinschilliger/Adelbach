# Adelbach

📹 Use your GoPro with a RaspberryPi for RTMP streaming – reliable 🧲

## 🏗️ Work in progress

Well, «reliable» is the goal, right now it's work in progress and more or less a copy of the PiVPN script. Feel free to help and contribute! 😊

# 🕹️ Installing

## Getting started

- Raspberry Pi with [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/) (Lite has better performance because there is less overhead) [installed](https://www.raspberrypi.org/documentation/installation/installing-images/README.md). Make sure you have Internet on the Ethernet port, as WiFi is used to communicate with the GoPro Camera. Create an empty file named «ssh» on the boot partition to [enable ssh access](https://www.raspberrypi.org/documentation/remote-access/ssh/README.md).
- Connect to your Pi via SSH, head over to the [documentation](https://www.raspberrypi.org/documentation/remote-access/ssh/unix.md) if you need help.
- TODO: Curl?

## 🛋 One-Step Automated Install:

Those who want to get started quickly and conveniently may install Pi-hole using the following command:

### `curl -sSL https://install.pi-hole.net | bash`

## ⚠️ [Piping to `bash` is controversial](https://pi-hole.net/2016/07/25/curling-and-piping-to-bash)

It prevents you from [reading code that is about to run](https://github.com/martinschilliger/Adelbach/master/auto_install/install.sh) on your system.

<!-- # Depends on
* [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/) -->

# 💁🏻 See also

- [gopro-py-api](https://github.com/KonradIT/gopro-py-api) by KonradIT.
