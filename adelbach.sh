#!/bin/bash

. /etc/adelbach/streamer.conf


function runFunc {
  /opt/adelbach/streamer.sh

  #Refresh GoPro real-time A/V stream
  curl "http://${GOPRO_IP}/gp/gpControl/execute?p1=gpStream&a1=proto_v2&c1=restart"

  #Send GoPro Hero4 UDP keep-alive packets
  /opt/adelbach/keepalive.sh
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
  echo ":::  -r, run          Start running stream"
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
"-r" | "run"               ) runFunc;;
"-c" | "config"               ) printconfigFunc;;
"-h" | "help"               ) helpFunc;;
"-u" | "uninstall"          ) uninstallFunc;;
"-v"                        ) versionFunc;;
*                           ) helpFunc;;
esac
