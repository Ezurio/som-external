#! /bin/bash

set -x -e

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

echo "WB50n_sysd POST BUILD script: starting..."

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_build_common_60.sh" "${BOARD_DIR}"  "${BUILD_TYPE}"  "${DEVEL_KEYS}"

[ ! -f "${TARGET_DIR}/lib/firmware/regulatory_50.db" ] || \
    ln -sfr "${TARGET_DIR}/lib/firmware/regulatory_50.db" "${TARGET_DIR}/lib/firmware/regulatory.db"

echo "WB50n_sysd POST BUILD script: done."
