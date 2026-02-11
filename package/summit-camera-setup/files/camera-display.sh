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

if v4l2-ctl -d "${CAM_DEV}" --list-formats | grep -q UYVY ; then
    format=UYVY
else
    format=YUY2
fi

if pgrep wayland >/dev/null 2>&1; then
    SINK=waylandsink
elif [ -r /sys/devices/soc0/soc_id ]; then
    read -r soc_id < /sys/devices/soc0/soc_id || soc_id=

    case "${soc_id}" in
        i.MX95)
            formatstr=",format=${format},framerate=5/1"
            SINK="videoconvert ! fbdevsink"
            ;;
        i.MX8MP)
            formatstr=""
            if media-ctl -d "${ID}" -p | grep -q 'pivariety'; then
                SINK="fbdevsink"
            else
                SINK="kmssink can-scale=false"
            fi
            ;;
        i.MX*)
            formatstr=",format=${format},framerate=5/1"
            SINK="videoconvert ! kmssink can-scale=false"
            ;;
        *)
            SINK="kmssink can-scale=false"
            formatstr=",format=${format}"
            ;;
    esac
else
    SINK="kmssink can-scale=false"
    formatstr=",format=${format}"
fi

set -- ${FORMAT}

gst-launch-1.0 v4l2src device="${CAM_DEV}" ! video/x-raw,width="${2}",height="${3}""${formatstr}" ! ${SINK}
