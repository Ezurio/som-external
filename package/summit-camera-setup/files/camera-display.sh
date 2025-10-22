#!/bin/sh

ID=${1:-/dev/media0}

SENSOR=$(media-ctl -d "${ID}" -p | sed -rn 's/- entity [0-9]+: (.* [0-9]+-[0-9a-f]+) \(.*/\1/p')
[ -n "${SENSOR}" ] || {
    echo "No camera found"
    exit 1
}

CSI_BRIDGE_NAME=$(media-ctl -d "${ID}" -p -e "${SENSOR}" | sed -rn 's/.*(cdns_csi2rx.*csi-bridge).*/\1/p')
CSI2RX_NAME=$(media-ctl -d "${ID}" -p -e "${CSI_BRIDGE_NAME}" | sed -rn 's/.*"(.*\.ticsi2rx)".*/\1/p')
CSI2RX_CONTEXT_NAME="${CSI2RX_NAME} context 0"
CAM_DEV=$(media-ctl -d "${ID}" -p -e "${CSI2RX_CONTEXT_NAME}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')
FORMAT="$(media-ctl -d "${ID}" -p -e "${CSI2RX_NAME}" | sed -rn 's/.*fmt:(.*)\/([0-9]+)x([0-9]+).*/\1 \2 \3/p')"

ls -d /sys/class/drm/card* >/dev/null 2>&1 || {
    echo "No display device found"
    exit 1
}

set -- ${FORMAT}

gst-launch-1.0 v4l2src device="${CAM_DEV}" ! video/x-raw,width="${2}",height="${3}",format=UYVY ! autovideosink
