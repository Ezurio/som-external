#! /bin/bash

set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SOM60 script: starting..."

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SOM60 script: done."
