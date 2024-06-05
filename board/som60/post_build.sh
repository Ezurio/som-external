#! /bin/bash

set -x -e

echo "SOM60 POST BUILD script: starting..."

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_build_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}" "${DEVEL_KEYS}"

[ ! -f "${TARGET_DIR}/lib/firmware/regulatory_60.db" ] || \
    ln -sfr "${TARGET_DIR}/lib/firmware/regulatory_60.db" "${TARGET_DIR}/lib/firmware/regulatory.db"

echo "SOM60 POST BUILD script: done."   
