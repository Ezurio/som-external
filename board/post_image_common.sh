#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

export BUILD_TYPE="${2}"

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON script: starting..."

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT=y" "${BR2_CONFIG}" \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false
export ENCRYPTED_TOOLKIT

grep -qF "BR2_SUMMIT_SECURE_BOOT=y" "${BR2_CONFIG}" \
	&& SECURE_BOOT=true || SECURE_BOOT=false
export SECURE_BOOT

die() { echo "$@" >&2; exit 1; }

mapfile -t < <(make -j1 -s --no-print-directory -C "${BASE_DIR}" \
	uboot-show-version swupdate-show-version | sed '/^make\[/d')
read -r UBOOT_VER SWUPDATE_VER <<< "${MAPFILE[@]}"
export UBOOT_VER SWUPDATE_VER

# Generate all build artifacts
"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_secure.sh"

if [ -f "${BINARIES_DIR}/sw-description" ]; then
	EMMC_DEVICE=$(grep -oP 'BR2_SUMMIT_EMMC_DEVICE=\K[^ ]+' "${BR2_CONFIG}")
	export EMMC_DEVICE

	# Call script to generate secure SWU
	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/generate_swu.sh"
fi

RELEASE_FILE="${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}${BR2_SUMMIT_BUILD_SUFFIX}-summit-${BR2_SUMMIT_BUILD_VERSION}.tar"

# Determine if we are building SD card image
case "${BUILD_TYPE}" in
*50*|*60*)
	case "${BUILD_TYPE}" in
	*sd)
		[ -n "${KEYS_DIR}" ] && BOOTEXT=cip || BOOTEXT=bin
		tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			"boot.${BOOTEXT}" u-boot.itb uboot.env kernel.itb rootfs.bin \
			mksdcard.sh mksdimg.sh
		;;
	*)
		tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			"${BR2_SUMMIT_PRODUCT}.swu"
		;;
	esac

	if [ -n "${KEYS_DIR}" ]; then
		# Secure boot build
		tar -rhSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			customer_key_sama5d3x.cip customer_key_sama5d3x_nk.cip \
			secure_mode_sama5d3x.cip secure_mode_sama5d3x_nk.cip

		[ -f "${BINARIES_DIR}/rodata_manifest.txt" ] && \
			tar -rhSf "${RELEASE_FILE}" --owner=root --group=root \
				-C "${BINARIES_DIR}" \
				rodata_manifest.txt
	fi
	;;

imx8*|am6*)
	tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		"${BR2_SUMMIT_PRODUCT}.swu" mksdcard.sh mksdimg.sh
	;;
esac

# Move back the OpenJDK 'modules' dependency to the target directory
# after creating the image and dependency tarball. Also, add the
# dependency tarball to the release archive
if grep -qF "BR2_SUMMIT_OPENJDK_GGV2=y" "${BR2_CONFIG}"
then
	# Delete the symlink and move back the original 'modules' file
	rm -f "${TARGET_DIR}/usr/lib/jvm/lib/modules"
	mv "${BINARIES_DIR}/jdk/lib/modules" "${TARGET_DIR}/usr/lib/jvm/lib/"

	# Delete the temporary 'jdk' directory
	rm -rf "${BINARIES_DIR}/jdk"

	# Add the dependency tarball to the release archive
	tar -C "${BINARIES_DIR}" -rhSf "${RELEASE_FILE}" \
		--owner=root --group=root openjdk.tar.gz
fi

bzip2 -f "${RELEASE_FILE}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON script: done."
