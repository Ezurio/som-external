#! /bin/bash

set -x -e

BOARD_DIR="$(realpath "$(dirname "${0}")")"
BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

echo "WB50n_sysd POST IMAGE script: starting..."

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}" "${DEVEL_KEYS}"

echo "WB50n_sysd POST IMAGE script: done."
