#!/bin/bash

# Author: Giulio Montagner
# https://gist.github.com/giu1io/d8d4695325a8d5cc429f
# Modifications: Martin Schilliger
# https://github.com/martinschilliger/Adelbach/

SCRIPT=adelbach

# source: http://raspberrypi.stackexchange.com/a/5121
# make sure we aren't running already
WHAT=`basename $0`
for p in `ps h -o pid -C $WHAT`; do
	if [ $p != $$ ]; then
		echo "${SCRIPT} was already running." >> $LOG
    exit 0
	fi
done

# Read variables in adelbach config file
. /etc/adelbach/streamer.conf

# source configuration
WLAN=wlan0
LOG=/var/log/adelbach.log
CHECK_INTERVAL=60

exec 1> /dev/null
exec 2>> $LOG
echo $(date) > $LOG

log(){
  echo $(date)" ${1}" >> $LOG
}

# without CHECK_INTERVAL set, we risk a 0 sleep = busy loop
if [ ! "$CHECK_INTERVAL" ]; then
	log "No check interval set!"
	exit 1
else
  sleep $CHECK_INTERVAL
fi

startAdelbach(){
  log "Starting ${SCRIPT}"
  $SCRIPT -s
}

stopAdelbach(){
  log "Stopping ${SCRIPT}"
  $SCRIPT -k
}

# initial start
curl --max-time 2 -sSf "http://${GOPRO_IP}/gp/gpControl/info" -o /dev/null & wait $!
if [ $? = 0 ]; then
  # Ok, camera is here, start streaming
  startAdelbach
fi

while [ 1 ]; do
  curl --max-time 2 -sSf "http://${GOPRO_IP}/gp/gpControl/info" -o /dev/null & wait $!
	if [ $? != 0 ]; then
    log "Could not connect to GoPro over WiFi. Is the WiFi up and running?"
    # Ok, WiFi is running. Otherwise we have to wait for the camera to come up anyway
    pgrep -n ffmpeg >> /dev/null
    if [ $? != 0 ]; then
      log "GoPro is running, but ffmpeg not. Attempting to restart ${SCRIPT}."
      stopAdelbach
      sleep 10 # we give it 10 seconds
      startAdelbach
    fi
  fi
	sleep $CHECK_INTERVAL
done
