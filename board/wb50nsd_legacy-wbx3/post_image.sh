#!/bin/bash

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE script: starting..."

UBOOT_VER=$(make -C "${BASE_DIR}" uboot-show-version | sed '/^make\[/d')

# Tooling checks
mkimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkimage
mkenvimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkenvimage

die() { echo "$@" >&2; exit 1; }

[ -x "${mkimage}" ] || \
	die "No mkimage found (uboot has not been built?)"

[ -x "${mkenvimage}" ] || \
	die "No mkenvimage found (uboot has not been built?)"

cp -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/image/u-boot.its" "${BINARIES_DIR}/u-boot.its"

TEXT_BASE=$(sed -rn 's,^CONFIG_TEXT_BASE=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")
sed -r -i "s/load = <.*>;/load = <${TEXT_BASE}>;/" "${BINARIES_DIR}/u-boot.its"

cd "${BINARIES_DIR}" 
${mkimage} -f u-boot.its u-boot.itb
ln -sf u-boot.itb boot.bin
cd -

# Generate U-Boot environment
ENV_SIZE=$(sed -rn 's,^CONFIG_ENV_SIZE=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")
${mkenvimage} -p 0 -s "${ENV_SIZE}" -o "${BINARIES_DIR}/uboot.env" "${TARGET_DIR}/etc/u-boot-initial-env"

# Copy mksdcard.sh and mksdimg.sh to images
ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/mksdcard.sh" "${BINARIES_DIR}/mksdcard.sh"
ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/mksdimg.sh" "${BINARIES_DIR}/mksdimg.sh"

if [ -n "${VERSION}" ]; then
	RELEASE_FILE="${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}-summit-${VERSION}.tar.bz2"
else
	RELEASE_FILE="${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}-summit.tar.bz2"
fi

tar -C "${BINARIES_DIR}" -cjf "${RELEASE_FILE}" \
	--owner=root --group=root \
	uboot.env mksdcard.sh mksdimg.sh boot.bin u-boot.itb

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE script: done."
