#!/bin/bash

. /etc/adelbach/streamer.conf

while true; do
  # GoPro 4 (keep alive)
  #sendip -p ipv4 -p udp -us 8554 -is 10.5.5.101 -ud 8554 -d "_GPHD_:1:0:2:0" ${GOPRO_IP}
  echo -ne "_GPHD_:0:0:2:0" > /dev/udp/${GOPRO_IP}/8554
  sleep 2.5
done
