#!/bin/sh

# Copyright (c) 2016, Ezurio
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#

# bttest.sh - manage bluetooth testing for the WB50 in production
#

ERROR_LOG="/var/log/bttest.log"
BT_PATH="/dev/ttyS4"
BT_PARAMS="0:0:19b2:0:0:0:0:0:0:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0"
# These parameters equate to:
# speed 115200 baud;
# line = 0;
# intr = <undef>; quit = <undef>; erase = <undef>; kill = <undef>; eof = <undef>;
# eol = <undef>; eol2 = <undef>; swtch = <undef>; start = <undef>;
# stop = <undef>; susp = <undef>; rprnt = <undef>; werase = <undef>;
# lnext = <undef>; flush = <undef>; min = 1; time = 1;
# parenb -parodd cs8 -hupcl -cstopb cread clocal -crtscts
# -ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon
# -ixoff -iuclc -ixany -imaxbel -iutf8
# -opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
# -isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop
# -echoprt -echoctl -echoke
#
# For a detailed description of the settings used please refer to the stty manpage.


do_() {
  echo -e "+ $@"; $@
}

display_usage() {
    echo "Use to set the WB50 into passthrough mode for production testing."
    echo
    echo "Action:"
    echo "  start - set test mode for Bluetooth"
    echo "  stop - set normal Bluetooth operation"
    echo
    echo "Usage:"
    echo "  ${0} [action] [/dev/ttyS*]"
    echo
}

bt_on_off()
{
  if [ ! -f /sys/class/gpio/pioE5/value ]; then
    echo 133 > /sys/class/gpio/export 2> /dev/null
    echo out > /sys/class/gpio/pioE5/direction
  fi

  echo ${1} > /sys/class/gpio/pioE5/value
}

exec 2>${ERROR_LOG}

case $1 in
    start) # Start testing Bluetooth on the specified port
        if [ $# -lt 2 ] || [ ! -c "${2}" ] || [ "${BT_PATH}" = "${2}" ]
        then
            display_usage
            exit 1
        fi

        if [ -e /tmp/bttest.rx.pid ] || [ -e /tmp/bttest.tx.pid ]
        then
            echo "Test mode running, exiting"
            exit 1
        fi

        echo "Using ${2} for passthrough."

        echo -n "Shutting down Bluetooth..."
        # Shutdown bt/smartbasic via the init script
        if ! /etc/init.d/S95bluetooth.bg stop > /dev/null
        then
            echo "failed!"
            exit 1
        fi
        echo "done."

        echo -n "Mapping reset pin and resetting..."
        # Initialize the bt reset gpio, and hold in reset
        bt_on_off 0
        echo "done."

        # Allow time for the radio to reset
        sleep 1

        echo -n "Releasing radio from reset..."
        # Enable the bt chip by releasing the reset gpio
        bt_on_off 1
        echo "done."

        echo -n "Loading Bluetooth firmware..."
        /usr/bin/bccmd -t bcsp -d ${BT_PATH} -b 115200 psload -r /lib/firmware/bluetopia/DWM-W311.psr >/dev/null
        echo "done."

        echo -n "Setting parameters for ports..."
        # Setup serial port baudrate + params
        stty -F ${BT_PATH} ${BT_PARAMS} > /dev/null
        stty -F ${2} ${BT_PARAMS} > /dev/null
        echo "done."

        echo -n "Setting up passthrough..."
        # Setup redirects/socat  (and background them)
        cat < ${2} > ${BT_PATH} &
        echo $! > /tmp/bttest.rx.pid
        cat < ${BT_PATH} > ${2} &
        echo $! > /tmp/bttest.tx.pid
        echo "done."

        echo
        echo "WB50 Bluetooth now in passthrough test mode."
    ;;

    stop) # Stop testing
        if [ ! -e /tmp/bttest.rx.pid ] || [ ! -e /tmp/bttest.tx.pid ]
        then
            echo "Test mode not running, exiting"
            exit 1
        fi

        echo -n "Mapping reset pin and resetting..."
        bt_on_off 0
        echo "done."

        echo -n "Tearing down passthrough..."
        # Kill the PID's of the passthrough
        read -r BT_RXPID < /tmp/bttest.rx.pid && kill ${BT_RXPID}
        read -r BT_TXPID < /tmp/bttest.tx.pid && kill ${BT_TXPID}
        rm -f /tmp/bttest*
        echo "done."

        sleep 1

        echo -n "Starting Bluetooth..."
        # Shutdown bt/smartbasic via the init script
        /etc/init.d/S95bluetooth.bg start > /dev/null
        echo "done."
    ;;

    *)
        display_usage
        exit 1
    ;;
esac
