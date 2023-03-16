#!/bin/bash

BOARD_DIR="$(dirname $0)"

set -x -e

support/scripts/genimage.sh -c $(dirname $0)/genimage.cfg

BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird"
[ -n "${VERSION}" ] && RELEASE_FILE+="-${VERSION}"

cp "${BOARD_DIR}"/sw-description "${BINARIES_DIR}"/
gzip -f "${BINARIES_DIR}/rootfs.ext2"
(cd "${BINARIES_DIR}" && echo -e "sw-description\nrootfs.ext2.gz" |\
	cpio -ov -H crc > "${BINARIES_DIR}/${BR2_LRD_PRODUCT}.swu")
tar -C "${BINARIES_DIR}" -cjf "${RELEASE_FILE}.tar.bz2" \
	sdcard.img ${BR2_LRD_PRODUCT}.swu
