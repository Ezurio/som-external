#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

BUILD_TYPE="${2}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON LEGACY script: starting..."

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

if grep -qF "BR2_LINUX_KERNEL_IMAGE_TARGET_CUSTOM=y" "${BR2_CONFIG}"; then
	# Generate all build artifacts
	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_secure.sh"
	ln -rsf "${BINARIES_DIR}/kernel.itb" "${BINARIES_DIR}/kernel.bin"
else
	ln -rsf "${BINARIES_DIR}/uImage"* "${BINARIES_DIR}/kernel.bin"
fi

ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/rootfs-additions-common/usr/bin/fw_select" "${BINARIES_DIR}/fw_select"
ln -rsf "${TARGET_DIR}"/usr/bin/fw_update "${BINARIES_DIR}/fw_update"
ln -rsf "${BINARIES_DIR}/boot.bin" "${BINARIES_DIR}/at91bs.bin"
ln -rsf "${BINARIES_DIR}/rootfs.ubi" "${BINARIES_DIR}/rootfs.bin"

if [ "${BUILD_TYPE}" = wb50n ]; then
	ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/wb50n/configs/sw-description" "${BINARIES_DIR}/sw-description"
	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/generate_swu.sh"
	mv "${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}.swu" "${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}-boot.swu"

	SWU_BOOT=${BR2_SUMMIT_PRODUCT}-boot.swu
else
	SWU_BOOT=""
fi

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/mkfwtxt.sh" "${BR2_SUMMIT_PRODUCT}-${BR2_SUMMIT_BUILD_VERSION}"
"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/mkfwusi.sh"

if [ ! -x "${TARGET_DIR}/usr/bin/dcas" ]; then
    sed '/\/etc\/dcas.conf/d' -i "${BINARIES_DIR}/fw.txt"
fi

# shellcheck disable=SC2086
tar -cjhSf "${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}-summit-${BR2_SUMMIT_BUILD_VERSION}.tar.bz2" \
	--owner=root --group=root -C "${BINARIES_DIR}" \
	at91bs.bin u-boot.bin kernel.bin rootfs.bin \
	fw_update fw_select fw_usi fw.txt ${SWU_BOOT}

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON LEGACY script: done."
