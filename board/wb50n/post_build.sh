BUILD_TYPE="${2}"

echo "WB50n POST BUILD legacy script: starting..."

# source the common post build legacy script
. ${BR2_EXTERNAL_LRD_SOM_PATH}/board/post_build_common_legacy.sh "${BUILD_TYPE}"

[ ! -f ${TARGET_DIR}/lib/firmware/regulatory_50.db ] || \
    ln -sfr ${TARGET_DIR}/lib/firmware/regulatory_50.db ${TARGET_DIR}/lib/firmware/regulatory.db

echo "WB50n POST BUILD script: done."
