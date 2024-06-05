#! /bin/bash

BOARD_DIR=$(realpath "$(dirname "${0}")")

BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD script: starting..."

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_build.sh" "${BINARIES_DIR}" "${BUILD_TYPE}" "${DEVEL_KEYS}"

rsync -rlptDWK --no-perms --exclude=.empty "${BOARD_DIR}/rootfs-additions/" "${TARGET_DIR}"

for f in "${TARGET_DIR}/usr/lib/NetworkManager/system-connections/"* "${TARGET_DIR}/etc/NetworkManager/system-connections/"* ; do
	if [ -f "${f}" ] ; then
		chmod 600 "${f}"
	fi
done

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD script: done."
