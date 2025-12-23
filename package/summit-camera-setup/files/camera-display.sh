#!/bin/sh

ID=${1:-/dev/media0}

ls -d /sys/class/drm/card* >/dev/null 2>&1 || {
    echo "No display device found"
    exit 1
}

SENSOR=$(media-ctl -d "${ID}" -p | sed -rn 's/- entity [0-9]+: (.* [0-9]+-[0-9a-f]+) \(.*/\1/p')
[ -n "${SENSOR}" ] || {
    echo "No camera found"
    exit 1
}

NODE_NEXT="${SENSOR}"
while [ -n "${NODE_NEXT}" ]; do
    NODE="${NODE_NEXT}"
	NODE_NEXT=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn '/^\s*->/{s/^\s*-> "(.*)".*/\1/p;q}')
done

FORMAT="$(media-ctl -d "${ID}" -p -e "${SENSOR}" | sed -rn 's/.*fmt:(.*)\/([0-9]+)x([0-9]+).*/\1 \2 \3/p')"
CAM_DEV=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')

format=$(v4l2-ctl -d 0 --list-formats-ext | sed -rn "s/\s+\[0\]: '([A-Z0-9]+)'.*/\1/p")
[ "${format}" != "YUYV" ] || format=YUY2

if pgrep wayland >/dev/null 2>&1; then
    SINK=waylandsink
elif [ -r /sys/devices/soc0/soc_id ]; then
    read -r soc_id < /sys/devices/soc0/soc_id || soc_id=

    case "${soc_id}" in
        i.MX93)
            format="${format},framerate=5/1"
            SINK="videoconvert ! kmssink can-scale=false"
            ;;
        i.MX95)
            format="${format},framerate=5/1"
            SINK="videoconvert ! fbdevsink"
            ;;
        *)
            SINK="kmssink can-scale=false"
            ;;
    esac
else
    SINK="kmssink can-scale=false"
fi

set -- ${FORMAT}

gst-launch-1.0 v4l2src device="${CAM_DEV}" ! video/x-raw,width="${2}",height="${3}",format="${format}" ! ${SINK}
