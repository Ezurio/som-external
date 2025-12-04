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

NODE="${SENSOR}"
while [ -n "${NODE}" ]; do
	NODE_NEXT=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn '/^\s*->/{s/^\s*-> "(.*)".*/\1/p;q}')
    NODE="${NODE_NEXT}"
done

FORMAT="$(media-ctl -d "${ID}" -p -e "${SENSOR}" | sed -rn 's/.*fmt:(.*)\/([0-9]+)x([0-9]+).*/\1 \2 \3/p')"
CAM_DEV=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')

set -- ${FORMAT}

if pgrep wayland >/dev/null 2>&1; then
    SINK=waylandsink
else
    SINK="kmssink can-scale=false"
fi

gst-launch-1.0 v4l2src device="${CAM_DEV}" ! video/x-raw,width="${2}",height="${3}",format=UYVY ! ${SINK}
