#!/bin/sh

trap 'rm -rf ${TMPDIR}' EXIT

IMGFILE=$1
ROOTFS_EXTRA_SIZE=${2:-0}
ROOTFSDIR=$3
SRCDIR=${0%/*}

BLOCK_SIZE=1024
MiBCONVERTER=$(( 1024 * 1024 ))

if [ -z "${IMGFILE}" ]; then
	echo "mksdimg.sh <output filename> [rootfs free space size in MiB] [rootfs source directory]" >&2
	exit 2
fi

if [ -z "${ROOTFSDIR}" ]; then
	if [ ! -f "${SRCDIR}/rootfs.tar" ]; then
		echo "Could not find required rootfs.tar file." >&2
		exit 2
	fi
elif [ ! -d "${ROOTFSDIR}" ]; then
	echo "Could not find requested rootfs directory: ${ROOTFSDIR}." >&2
	exit 2
fi

[ "${ROOTFS_EXTRA_SIZE}" -eq "${ROOTFS_EXTRA_SIZE}" ] 2>/dev/null
if [ $? -ne 0 ]; then
	echo "rootfs free space size is not a number" >&2
	exit 2
fi

set -e

echo "[Creating card image...]"

# Calculate size of the rootfs file system
ROOTFS_FILE_SIZE=$(stat -c%s "${SRCDIR}/rootfs.tar")

# Set image free space to 120 % of the used space by default
if [ "${ROOTFS_EXTRA_SIZE}" -eq 0 ]; then
	ROOTFS_EXTRA_SIZE=$(( ROOTFS_FILE_SIZE * 12 / 10 ))
else
	ROOTFS_EXTRA_SIZE=$(( ROOTFS_EXTRA_SIZE * MiBCONVERTER ))
fi

# Calculate partitions
BOOT_IMG_SIZE_MiB=48
BOOT_LBS=512
BOOT_BLOCKS=$(( BOOT_IMG_SIZE_MiB * MiBCONVERTER / BLOCK_SIZE ))

SWAP_IMG_SIZE_MiB=256

ROOTFS_IMG_SIZE_MiB=$(( (ROOTFS_FILE_SIZE + ROOTFS_EXTRA_SIZE) / MiBCONVERTER + 1 ))
ROOTFS_BLOCKS=$(( ROOTFS_IMG_SIZE_MiB * MiBCONVERTER / BLOCK_SIZE ))

BOOT_START_MiB=1
BOOT_END_MiB=$((BOOT_START_MiB + BOOT_IMG_SIZE_MiB))

SWAP_START_MiB=${BOOT_END_MiB}
SWAP_END_MiB=$((SWAP_START_MiB + SWAP_IMG_SIZE_MiB))

ROOTFS_START_MiB=${SWAP_END_MiB}
ROOTFS_END_MiB=$(( ROOTFS_START_MiB + ROOTFS_IMG_SIZE_MiB ))

TMPDIR=$(mktemp -d)
IMGTMPFILE=${TMPDIR}/${IMGFILE##*/}

# Create disk image placeholder
fallocate -l ${BOOT_START_MiB}MiB ${IMGTMPFILE}

echo "[Creating boot partition...]"

# Create boot partition image
mkfs.vfat -F 16 -n BOOT -S ${BOOT_LBS} -C ${TMPDIR}/boot.img ${BOOT_BLOCKS} > /dev/null

# Add files to boot partition image
mcopy -i ${TMPDIR}/boot.img ${SRCDIR}/boot.bin ::/
mcopy -i ${TMPDIR}/boot.img ${SRCDIR}/u-boot.itb ::/
mcopy -i ${TMPDIR}/boot.img ${SRCDIR}/kernel.itb ::/
mcopy -i ${TMPDIR}/boot.img ${SRCDIR}/uboot.env ::/

# Add boot partition to disk image
cat ${TMPDIR}/boot.img >> ${IMGTMPFILE}
rm -f ${TMPDIR}/boot.img

echo "[Creating swap partition...]"

# Create swap partition image
fallocate -l ${SWAP_IMG_SIZE_MiB}MiB ${TMPDIR}/swap.img
chmod 600 ${TMPDIR}/swap.img

# Format swap partition image
mkswap -L swap ${TMPDIR}/swap.img > /dev/null

# Add swap partition to disk image
cat ${TMPDIR}/swap.img >> ${IMGTMPFILE}
rm -f ${TMPDIR}/swap.img

echo "[Creating rootfs partition...]"

# Create rootfs directory for mkfs.ext4
if [ -z "${ROOTFSDIR}" ]; then
	ROOTFSDIR=${TMPDIR}/rootfs.tmp
	mkdir ${ROOTFSDIR}
	tar xf ${SRCDIR}/rootfs.tar -C ${ROOTFSDIR}
fi

# Create rootfs partition image
HOST_MKFS=${SRCDIR}/../host/sbin/mkfs.ext4
[ -f ${HOST_MKFS} ] || HOST_MKFS=mkfs.ext4

fakeroot ${HOST_MKFS} -q -L rootfs -F -b ${BLOCK_SIZE} -d ${ROOTFSDIR} \
	-E lazy_itable_init=0,lazy_journal_init=0 ${TMPDIR}/rootfs.img ${ROOTFS_BLOCKS}
rm -rf ${TMPDIR}/rootfs.tmp

# Add rootfs partition to disk image
cat ${TMPDIR}/rootfs.img >> ${IMGTMPFILE}
rm -f ${TMPDIR}/rootfs.img

# Create image partition table
parted -s ${IMGTMPFILE} mklabel msdos unit MiB \
	mkpart primary fat16 ${BOOT_START_MiB} ${BOOT_END_MiB} set 1 lba on set 1 boot on \
	mkpart primary linux-swap ${SWAP_START_MiB} ${SWAP_END_MiB} \
	mkpart primary ext4 ${ROOTFS_START_MiB} 100%

echo "[Compressing card image...]"
xz -9cT 0 ${IMGTMPFILE} > ${IMGFILE}.xz

echo "[Image file: ${IMGFILE}.xz]"
echo "SD Card Programming: umount /dev/sdX? ; xz -dc ${IMGFILE}.xz | sudo dd of=/dev/sdX bs=4M conv=fsync"

rm -rf ${TMPDIR}
sync

echo "[Done]"
