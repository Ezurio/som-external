BOARD_DIR="$(realpath $(dirname $0))"
BUILD_TYPE="${2}"
DEVEL_KEYS="${3}"

. "${BOARD_DIR}/../post_build_common_60.sh" "${BOARD_DIR}" "${BUILD_TYPE}" "${DEVEL_KEYS}"

[ ! -f ${TARGET_DIR}/lib/firmware/regulatory_60.db ] || \
    ln -sfr ${TARGET_DIR}/lib/firmware/regulatory_60.db ${TARGET_DIR}/lib/firmware/regulatory.db


if ! grep -qF "BR2_PACKAGE_SONA_FIRMWARE_NX61X=y" ${BR2_CONFIG}; then
    SONA_NX_MODPROBE_CONFIG=${TARGET_DIR}/etc/modprobe.d/moal.conf

    if [ -f ${SONA_NX_MODPROBE_CONFIG} ];  then
        rm -f ${SONA_NX_MODPROBE_CONFIG}
    fi
fi
