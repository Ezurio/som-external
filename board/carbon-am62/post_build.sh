#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD CARBON_AM62 script: starting..."

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_build_common.sh" "${BOARD_DIR}" "${BUILD_TYPE}"

cp "${BUILD_DIR}"/ti-k3-boot-firmware-*/ti-ipc/am62xx/am62-mcu-m4f0_0-fw \
	"${TARGET_DIR}/lib/firmware/"

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD CARBON_AM62 script: done."
