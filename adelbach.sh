#!/bin/bash

. /etc/adelbach/streamer.conf

USERID="$(id -u)"
PIDPATH="/var/run/user/${USERID}/adelbach"


function streamFunc {
  #Refresh GoPro real-time A/V stream
  curl -sSf "http://${GOPRO_IP}/gp/gpControl/execute?p1=gpStream&a1=proto_v2&c1=restart" -o /dev/null

  # create directory for pid files
  mkdir -p ${PIDPATH}

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

  echo ${!} >> ${PIDPATH}/ffmpeg.pid

  #Send GoPro keep-alive packets
  /opt/adelbach/keepalive.sh &
  echo ${!} >> ${PIDPATH}/keepalive.pid
}

function killFunc {
  echo "Called adelbach kill. Trying to kill all adelbach-related processes including ffmpeg."
  sudo pkill -F ${PIDPATH}/ffmpeg.pid
  rm ${PIDPATH}/ffmpeg.pid
  sudo pkill -F ${PIDPATH}/keepalive.pid
  rm ${PIDPATH}/keepalive.pid
}

function uninstallFunc {
  sudo /opt/adelbach/uninstall.sh
}

function versionFunc {
  printf "\e[1mVersion 0.1\e[0m\n"
}

function printconfigFunc {
  CONFURL="/etc/adelbach/streamer.conf"
  printf "The configuration is stored in \e[1m${CONFURL}\e[0m\n"
  printf "Here is the content of this file:\n\n"
  printf "$(cat ${CONFURL})\n"
}

function helpFunc {
  echo "::: Control all Adelbach specific functions!"
  echo ":::"
  echo "::: Usage: adelbach <command>"
  echo ":::"
  echo "::: Commands:"
  echo ":::  -s, stream       Start running stream"
  echo ":::  -k, kill         Stop running stream"
  echo ":::  -c, config       Show the configuration file"
  echo ":::  -h, help         Show this help dialog"
  echo ":::  -u, uninstall    Uninstall Adelbach from your system!"
  exit 1
}

if [[ $# = 0 ]]; then
  helpFunc
fi

# Handle redirecting to specific functions based on arguments
case "$1" in
"-s" | "stream"             ) streamFunc;;
"-k" | "kill"               ) killFunc;;
"-c" | "config"             ) printconfigFunc;;
"-h" | "help"               ) helpFunc;;
"-u" | "uninstall"          ) uninstallFunc;;
"-v"                        ) versionFunc;;
*                           ) helpFunc;;
esac
