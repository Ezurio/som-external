BUILD_TYPE="${2}"

echo "WB45n POST BUILD script: starting..."

# source the common post build script
. ${BR2_EXTERNAL_LRD_SOM_PATH}/board/post_build_common_legacy.sh "${BUILD_TYPE}"

[ ! -f ${TARGET_DIR}/lib/firmware/regulatory_45.db ] || \
    ln -sfr ${TARGET_DIR}/lib/firmware/regulatory_45.db ${TARGET_DIR}/lib/firmware/regulatory.db

echo "WB45n POST BUILD script: done."
