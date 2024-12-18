#! /bin/bash

set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD SOM60 script: starting..."

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_build_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}"

[ ! -f "${TARGET_DIR}/lib/firmware/regulatory_60.db" ] || \
    ln -sfr "${TARGET_DIR}/lib/firmware/regulatory_60.db" "${TARGET_DIR}/lib/firmware/regulatory.db"

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD SOM60 script: done."
