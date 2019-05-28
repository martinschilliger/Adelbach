#!/bin/bash

. /etc/adelbach/streamer.conf

while true; do
  echo -ne "_GPHD_:0:0:2:0" > /dev/udp/${GOPRO_IP}/8554
  sleep 2.5
done
