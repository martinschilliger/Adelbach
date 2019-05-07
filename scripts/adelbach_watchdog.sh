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
else sleep $CHECK_INTERVAL
fi

restartWifi () {
	dhclient -v -r

	ifconfig $WLAN down
	ifconfig $WLAN up
}

startAdelbach(){
  log "Starting ${SCRIPT}"
  $SCRIPT -s
}

stopAdelbach(){
  log "Stopping ${SCRIPT}"
  pkill -x "$SCRIPT"
  pkill -x "ffmpeg"
}

while [ 1 ]; do
	ping -c 1 $GOPRO_IP & wait $!
	if [ $? != 0 ]; then
		log "Could not find GoPro. Attempting restart WiFi and ${SCRIPT}"
    stopAdelbach
		restartWifi
  else
  	pgrep -n ffmpeg >> /dev/null
    if [ "$?" != 0 ]; then # looks inverse, but works. Don't know why…
      log "GoPro is running, but ffmpeg not. Attempting restart ${SCRIPT} only."
      stopAdelbach
      startAdelbach
    fi
	fi
	sleep $CHECK_INTERVAL
done
