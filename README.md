# Adelbach

📹 Use your GoPro with a RaspberryPi for RTMP streaming – reliable 🧲

🏗️ **Work in progress**! Well, «reliable» is the goal, right now it's work in progress and more or less a copy of the PiVPN script. Feel free to help and contribute! 😊

# 🕹️ Installing

## Getting started

- Raspberry Pi with [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/) (Lite has better performance because there is less overhead) [installed](https://www.raspberrypi.org/documentation/installation/installing-images/README.md). Make sure you have Internet on the Ethernet port, as WiFi is used to communicate with the GoPro Camera. Create an empty file named «ssh» on the boot partition to [enable ssh access](https://www.raspberrypi.org/documentation/remote-access/ssh/README.md).
- Connect to your Pi via SSH, head over to the [documentation](https://www.raspberrypi.org/documentation/remote-access/ssh/unix.md) if you need help.
- TODO: Curl installed?

## 🛋 One-Step Automated Install:

Those who want to get started quickly and conveniently may install Pi-hole using the following command:

### `curl -L https://github.com/martinschilliger/Adelbach/raw/master/auto_install/install.sh | bash`

⚠️ [Piping to `bash` is controversial](https://pi-hole.net/2016/07/25/curling-and-piping-to-bash). It prevents you from [reading code that is about to run](https://github.com/martinschilliger/Adelbach/tree/master/auto_install/install.sh) on your system.

### Open Tasks

Adelbach could do more. For example the configuration of ffmpeg could be fixed with different camera profiles or different Raspberry Pi Performances. If you are into optimization, have a look at [KonradIT's nice overview](https://github.com/KonradIT/goprowifihack/blob/master/HERO4/WifiCommands.md#streaming-tweaks) where to start tweaking.

<!-- # Depends on
* [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/) -->

# 💁🏻 See also

- [gopro-py-api](https://github.com/KonradIT/gopro-py-api) by KonradIT.
- [goprowifihack](https://github.com/KonradIT/goprowifihack) also by KonradIT. Espacially [Livestreaming.md](https://github.com/KonradIT/goprowifihack/blob/master/HERO4/Livestreaming.md) looks interesting.- [gopro-console](https://github.com/m6c7l/gopro-console) by m6c7l
- [gopro-youtube-livestream](https://github.com/lamvann/gopro-youtube-livestream) by lamvann
- [H7 – GoPro Live Streaming](http://community.h7.org/topic/577/gopro-live-streaming) by Yatko

# 🙏 Donation

If you want to donate, please look out for projects in need or consider you local [salvation army](https://www.salvationarmy.org). Thank you!
