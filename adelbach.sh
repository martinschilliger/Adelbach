#!/bin/bash

. /etc/adelbach/streamer.conf


function streamFunc {
  #Refresh GoPro real-time A/V stream
  curl "http://${GOPRO_IP}/gp/gpControl/execute?p1=gpStream&a1=proto_v2&c1=restart"

  /opt/adelbach/streamer.sh &

  #Send GoPro keep-alive packets
  /opt/adelbach/keepalive.sh &
}

function killFunc {
  echo "Called adelbach kill. Trying to kill all adelbach-related processes including ffmpeg."
  pkill -f "/bin/bash /opt/adelbach/keepalive.sh" > /dev/null &
  pkill -f "sleep 2.5" > /dev/null &
  pkill -x ffmpeg > /dev/null &
  pkill -x adelbach > /dev/null &
  exit 1
}

function uninstallFunc {
  sudo /opt/adelbach/uninstall.sh
  exit 1
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
