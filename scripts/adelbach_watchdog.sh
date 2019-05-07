#!/bin/bash

# Author: Giulio Montagner
# https://gist.github.com/giu1io/d8d4695325a8d5cc429f
# Modifications: Martin Schilliger
# https://github.com/martinschilliger/Adelbach/

SCRIPT=adelbach

# source: http://raspberrypi.stackexchange.com/a/5121
# make sure we aren't running already
what=`basename $0`
for p in `ps h -o pid -C $what`; do
	if [ $p != $$ ]; then
		exit 0
	fi
done

. /etc/adelbach/streamer.conf

# source configuration
wlan=wlan0
log=/var/log/wifi.log
check_interval=120

exec 1> /dev/null
exec 2>> $log
echo $(date) > $log
# without check_interval set, we risk a 0 sleep = busy loop
if [ ! "$check_interval" ]; then
	echo "No check interval set!" >> $log
	exit 1
else sleep $check_interval
fi

restartWifi () {
	dhclient -v -r
	# make really sure
	killall dhclient
	ifconfig $wlan down
	ifconfig $wlan up
}

startAdelbach(){
  $SCRIPT -s
}

stopAdelbach(){
  pkill -x "$SCRIPT"
  pkill -x "ffmpeg"
}

while [ 1 ]; do
	ping -c 1 $GOPRO_IP & wait $!
	if [ $? != 0 ]; then # could not find GoPro
		echo $(date)" attempting restart..." >> $log
    stopAdelbach
		restartWifi
  else # found GoPro, test if ffmpeg is running
  	pgrep -n ffmpeg >> /dev/null
    if [ "$?" != 0 ]; then # looks inverse, but works. Don't know why…
      echo $(date)" WiFi running, but ffmpeg not. Attempting restart adelbach only..." >> $log
    fi
    stopAdelbach
    startAdelbach
	fi
	sleep $check_interval
done
