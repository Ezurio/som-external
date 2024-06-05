#!/bin/sh

bt_on_off()
{
	if [ ! -f /sys/class/gpio/pioE5/value ]; then
		echo 133 > /sys/class/gpio/export 2> /dev/null
		echo out > /sys/class/gpio/pioE5/direction
	fi

	echo "${1}" > /sys/class/gpio/pioE5/value
}

case "${1}" in
	start)
		bt_on_off 1

		/usr/bin/bccmd -t bcsp -d /dev/ttyS4 -b 115200 psload -r /lib/firmware/bluetopia/DWM-W311.psr >/dev/null
		/usr/bin/hciattach -p /dev/ttyS4 bcsp 115200 >/dev/null
		;;

	stop)
		hciconfig hci0 down
		killall hciattach

		usleep 200000

		bt_on_off 0
		;;

	*)
		echo "Usage: ${0} <start|stop>"
		exit 1
		;;
esac
