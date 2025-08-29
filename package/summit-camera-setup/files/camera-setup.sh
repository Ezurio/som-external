#!/bin/sh

SENSOR=$(media-ctl -d "${1}" -p | sed -rn 's/- entity [0-9]+: (.* [0-9]+-[0-9a-f]+) \(.*/\1/p')

# BD LCD panels are 1280x800, thus the format choice
case "${SENSOR}" in
	ov5640*|*pivariety*)
		OV564x_CAM_FMT="[fmt:UYVY/1280x720]"
		;;
	ov5645*)
		OV564x_CAM_FMT="[fmt:UYVY/1280x960]"
		;;
	*)
		exit 0
		;;
esac

CSI_BRIDGE_NAME=$(media-ctl -d "${1}" -p -e "${SENSOR}" | sed -rn 's/.*(cdns_csi2rx.*csi-bridge).*/\1/p')
CSI2RX_NAME=$(media-ctl -d "${1}" -p -e "${CSI_BRIDGE_NAME}" | sed -rn 's/.*"(.*\.ticsi2rx)".*/\1/p')

media-ctl -d 0 --set-v4l2 "\"${SENSOR}\":0 ${OV564x_CAM_FMT}"
media-ctl -d 0 --set-v4l2 "\"${CSI_BRIDGE_NAME}\":0 ${OV564x_CAM_FMT}"
media-ctl -d 0 --set-v4l2 "\"${CSI2RX_NAME}\":0 ${OV564x_CAM_FMT}"

CSI2RX_CONTEXT_NAME="${CSI2RX_NAME} context 0"
CAM_SUBDEV=$(media-ctl -d "${1}" -p -e "${SENSOR}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')
CAM_DEV=$(media-ctl -d "${1}" -p -e "${CSI2RX_CONTEXT_NAME}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')
num=${1#/dev/media}
ln -snf "${CAM_DEV}" "/dev/video-${SENSOR%% *}-cam${num}"
ln -snf "${CAM_SUBDEV}" "/dev/v4l-${SENSOR%% *}-subdev${num}"
