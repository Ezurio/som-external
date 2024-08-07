#!/bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio
#
# Generate all secure image artificats
#
# Inputs - must be located in BINARIES_DIR:
#
#	keys/key.bin			U-Boot symmetric encryption key
#	keys/key-iv.bin			U-Boot symmetric encryption iv
#	boot.scr			Kernel boot script template
#	u-boot-spl.dtb			U-Boot SPL FDT
#	u-boot.its			U-Boot FIT image script
#	u-boot.dtb			U-Boot FDT
#	kernel.its			Kernel FIT image descriptor
#	zImage				Kernel
#	at91-??.dtb			Kernel FDT
#	rootfs.squashfs			rootFS
#
# Secured artifacts generated in BINARIES_DIR:
#
#	boot.bin			U-Boot SPL
#	u-boot.itb			U-Boot FIT (encrypted)
#	kernel.itb			Kernel FIT (signed)
#

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SECURE script: starting..."

SD=${1:-false}

# enable tracing and exit on errors
set -x -e

die() { echo "$@" >&2; exit 1; }

grep -qF "SALT" "${BINARIES_DIR}/boot.scr" && SECURE_ROOTFS=true || SECURE_ROOTFS=false

[ -n "${UBOOT_VER}" ] ||
	UBOOT_VER=$(make -C "${BASE_DIR}" uboot-show-version)

# Secure tooling checks
mkimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkimage
atmel_pmecc_params=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/atmel_pmecc_params
openssl=$(command -v openssl)
veritysetup=${HOST_DIR}/sbin/veritysetup

[ -x "${mkimage}" ] || \
	die "No mkimage found (uboot has not been built?)"
[ -x "${openssl}" ] || \
	die "no openssl found"
[ -x "${atmel_pmecc_params}" ] || ${SD} || \
	die "no atmel_pmecc_params found (uboot has not been built?)"
[ -x "${veritysetup}" ] || ! ${SECURE_ROOTFS} || \
	die "No veritysetup found (host-cryptsetup has not been built?)"

echo "# entering ${BINARIES_DIR} for this script"
cd "${BINARIES_DIR}"

# Create keys if not present
if [ ! -f keys/key.bin ]; then
	mkdir -p keys
	# Create random key, for AES128, key is 16 bytes long
	dd if=/dev/random of=keys/key.bin bs=16 count=1
	# Create random IV, AES block is 16 bytes, regardless of key size
	dd if=/dev/random of=keys/key-iv.bin bs=16 count=1
fi

# Create unsecured_images dir and copy off unsigned images
mkdir -p unsecured_images
cp -ft unsecured_images u-boot.dtb u-boot-spl.dtb

# Backup kernel boot script (with no verity hash) for release artifacts
cp -f boot.scr boot.scr.nohash

# Check if we are creating secure rootfs
if ${SECURE_ROOTFS} ; then
	# Generate the hash table for squashfs
	rm -f rootfs.verity
	${veritysetup} format rootfs.squashfs rootfs.verity > rootfs.verity.header
	# Get the root hash
	HASH=$(awk '/Root hash:/ {print $3}' rootfs.verity.header)
	SALT=$(awk '/Salt:/ {print $2}' rootfs.verity.header)
	BLOCKS=$(awk '/Data blocks:/ {print $3}' rootfs.verity.header)
	SIZE=$((BLOCKS * 8))
	OFFSET=$((BLOCKS + 1))

	# Generate a combined rootfs
	rm -f rootfs.bin
	cat rootfs.squashfs rootfs.verity > rootfs.bin

	# Generate the kernel boot script
	sed -i -e "s/SALT/${SALT}/g" -e "s/HASH/${HASH}/g" -e "s/BLOCKS/${BLOCKS}/g" -e "s/SIZE/${SIZE}/g" -e "s/OFFSET/${OFFSET}/g" boot.scr
fi

# Create Kernel FIT image, and store signature in u-boot
${mkimage} -f kernel.its kernel-nosig.itb
${mkimage} -f kernel.its -F -K u-boot.dtb -k keys -r kernel.itb

# Create U-Boot FIT image (encrypted), and store key, IV and signature in SPL
${mkimage} -f u-boot.its -F -K u-boot-spl.dtb -k keys -r u-boot.itb

# Create final SPL FIT with appended keyed DTB
cat u-boot-spl-nodtb.bin u-boot-spl.dtb > u-boot-spl.bin

if ${SD} ; then
	${mkimage} -T atmelimage -d "${BINARIES_DIR}/u-boot-spl.bin" "${BINARIES_DIR}/boot.bin"
else
	# Generate Atmel PMECC boot.bin from SPL
	${mkimage} -T atmelimage -n "$(${atmel_pmecc_params})" -d u-boot-spl.bin boot.bin
	# Save off the raw PMECC header
	dd if=boot.bin of=pmecc.bin bs=208 count=1
fi

# Restore unsecured components
mv -ft ./ unsecured_images/*
rm -rf unsecured_images/
mv -f boot.scr.nohash boot.scr

cd -

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SECURE script: done."
