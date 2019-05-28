#!/bin/bash
### BEGIN INIT INFO
# Provides:          adelbach_watchdog
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Adelbach Watchdog service for Wi-Fi
# Description:       This script ping the router every N seconds and if it fails
#                    tries to restore the network connection. Depending on this it
#                    starts and stops Adelbach RTMP Straming
### END INIT INFO
# this file goes in /etc/init.d/
# Author: Giulio Montagner
# https://gist.github.com/giu1io/d8d4695325a8d5cc429f
# Modifications: Martin Schilliger
# https://github.com/martinschilliger/Adelbach/

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
DESC="Description of the service"
NAME=adelbach_watchdog
DAEMON=/opt/adelbach/$NAME.sh
DAEMON_PS=$NAME.sh # TODO: not shure if this is correct! => it was /[r]oot/$NAME.sh
DAEMON_ARGS="--options args"
#PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

#Include functions
. /lib/lsb/init-functions


#
# Function that starts the daemon/service
#
do_start() {
	# Return
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	# make sure we aren't running already
	what=$(basename $DAEMON)
	for p in `ps h -o pid -C $what`; do
		if [ $p != $$ ]; then
			return 1
		fi
	done
	$DAEMON &
	return 0
}

#
# Function that stops the daemon/service
#
do_stop() {
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	#   other if a failure occurred
	kill -9 $(ps aux | grep "$DAEMON_PS" | awk '{print $2}')
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
	#
	# If the daemon can reload its configuration without
	# restarting (for example, when it is sent a SIGHUP),
	# then implement that here.
	#
	return 0
}

case "$1" in
  start)
  	[ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
  	do_start
  	case "$?" in
  		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
  		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
  	esac
  	;;
  stop)
  	[ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
  	do_stop
  	case "$?" in
  		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
  		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
  	esac
  	;;
  status)
  	ps aux | grep "$DAEMON_PS"
  	;;
    #reload|force-reload)
  	#
  	# If do_reload() is not implemented then leave this commented out
  	# and leave 'force-reload' as an alias for 'restart'.
  	#
  	#log_daemon_msg "Reloading $DESC" "$NAME"
  	#do_reload
  	#log_end_msg $?
  	#;;
  restart|force-reload)
  	#
  	# If the "reload" option is implemented then remove the
  	# 'force-reload' alias
  	#
  	log_daemon_msg "Restarting $DESC" "$NAME"
  	do_stop
  	case "$?" in
  	  0|1)
  		do_start
  		case "$?" in
  			0) log_end_msg 0 ;;
  			1) log_end_msg 1 ;; # Old process is still running
  			*) log_end_msg 1 ;; # Failed to start
  		esac
  		;;
	  *)
  		# Failed to stop
  		log_end_msg 1
  		;;
	esac
	;;
  *)
	#echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
	exit 3
	;;
esac

:
