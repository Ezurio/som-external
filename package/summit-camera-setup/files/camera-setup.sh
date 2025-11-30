#!/bin/sh

ID=${1:-/dev/media0}

SENSOR=$(media-ctl -d "${ID}" -p | sed -rn 's/- entity [0-9]+: (.* [0-9]+-[0-9a-f]+) \(.*/\1/p')

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

NODE_NEXT="\"${SENSOR}\":0"
while true; do
	NODE="${NODE_NEXT%\"*}"
	NODE="${NODE#\"}"

	media-ctl -d "${ID}" -p -e "${NODE}" | grep -q 'V4L2 subdev' || break
	media-ctl -d "${ID}" --set-v4l2 "${NODE_NEXT} ${OV564x_CAM_FMT}"

	NODE_NEXT=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn 's/\s*-> (".*"[^ ]*).*/\1/p')
	[ -n "${NODE_NEXT}" ] || break
done

CAM_SUBDEV=$(media-ctl -d "${ID}" -p -e "${SENSOR}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')
CAM_DEV=$(media-ctl -d "${ID}" -p -e "${NODE}" | sed -rn 's/\s+device node name ([^ ]+)/\1/p')

num=${ID#/dev/media}
ln -snf "${CAM_DEV}" "/dev/video-${SENSOR%% *}-cam${num}"
ln -snf "${CAM_SUBDEV}" "/dev/v4l-${SENSOR%% *}-subdev${num}"
