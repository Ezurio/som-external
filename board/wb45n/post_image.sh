#! /bin/bash

set -x -e

BUILD_TYPE="${2}"

echo "WB45n POST IMAGE script: starting..."

# source the common post image script
"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_common_legacy.sh" "${BUILD_TYPE}"

echo "WB45n POST IMAGE script: done."
