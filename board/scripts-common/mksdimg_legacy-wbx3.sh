#!/bin/sh

trap 'rm -rf ${TMPDIR}' EXIT

IMGFILE=$1
SRCDIR=${0%/*}

BLOCK_SIZE=1024
MiBCONVERTER=$(( 1024 * 1024 ))

if [ -z "${IMGFILE}" ]; then
	echo "mksdimg.sh <output filename>" >&2
	exit 2
fi

set -e

echo "[Creating card image...]"

# Calculate partitions
BOOT_IMG_SIZE_MiB=48
BOOT_LBS=512
BOOT_BLOCKS=$(( BOOT_IMG_SIZE_MiB * MiBCONVERTER / BLOCK_SIZE ))

BOOT_START_MiB=1

TMPDIR=$(mktemp -d)
IMGTMPFILE=${TMPDIR}/${IMGFILE##*/}

# Create disk image placeholder
fallocate -l ${BOOT_START_MiB}MiB "${IMGTMPFILE}"

echo "[Creating boot partition...]"

# Create boot partition image
mkfs.vfat -F 16 -n BOOT -S ${BOOT_LBS} -C "${TMPDIR}/boot.img" ${BOOT_BLOCKS} > /dev/null

# Add files to boot partition image
mcopy -i "${TMPDIR}/boot.img" "${SRCDIR}/boot.bin" ::/
mcopy -i "${TMPDIR}/boot.img" "${SRCDIR}/u-boot.itb" ::/
mcopy -i "${TMPDIR}/boot.img" "${SRCDIR}/uboot.env" ::/

# Add boot partition to disk image
cat "${TMPDIR}/boot.img" >> "${IMGTMPFILE}"
rm -f "${TMPDIR}/boot.img"

# Create image partition table
parted -s "${IMGTMPFILE}" mklabel msdos unit MiB \
	mkpart primary fat16 ${BOOT_START_MiB} ${BOOT_IMG_SIZE_MiB} set 1 lba on set 1 boot on

echo "[Compressing card image...]"
xz -9cT 0 "${IMGTMPFILE}" > "${IMGFILE}.xz"

echo "[Image file: ${IMGFILE}.xz]"
echo "SD Card Programming: umount /dev/sdX? ; xz -dc ${IMGFILE}.xz | sudo dd of=/dev/sdX bs=4M conv=fsync"

rm -rf "${TMPDIR}"
sync

echo "[Done]"
