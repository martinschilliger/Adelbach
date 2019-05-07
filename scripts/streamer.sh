#!/bin/bash

. /etc/adelbach/streamer.conf

#Start streaming to rtmp with custom URL

ffmpeg \
  -thread_queue_size 2048 -fflags nobuffer -f:v mpegts -probesize 65536 \
  -i "$SOURCE" -deinterlace -c:v libx264 -r $FPS -g $(($FPS * 2)) -b:v $VBR \
  -c:a aac -ar 44100 -ac $AUDIO_CHANNELS -b:a $(($AUDIO_CHANNELS * 64))k \
  -preset $QUAL -flags +global_header \
  -maxrate 1.5M -bufsize 3M \
  -loglevel $LOGLEVEL \
  -f flv "$RTMP_URL" &

#-tune zerolatency
# -pix_fmt yuv420p
# -vf scale=-1:480
