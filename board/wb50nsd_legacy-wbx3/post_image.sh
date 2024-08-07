#!/bin/bash

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE script: starting..."

# Tooling checks
mkenvimage="${BUILD_DIR}/uboot-custom/tools/mkenvimage"

die() { echo "$@" >&2; exit 1; }

[ -x "${mkenvimage}" ] || \
	die "No mkenvimage found (uboot has not been built?)"

${mkenvimage} -p 0 -s 131072 -o "${BINARIES_DIR}/uboot.env" "${BINARIES_DIR}/u-boot-initial-env"

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
