#! /bin/bash

BOARD_DIR=$(realpath "$(dirname "${0}")")
BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}" "${DEVEL_KEYS}"
