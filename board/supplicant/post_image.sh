BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: starting..."

# enable tracing and exit on errors
set -x -e

mkdir -p "${BINARIES_DIR}"

case "${BR2_LRD_PRODUCT}" in
*legacy*)
	PKGNAME="(sdcsupp|sdccli|sdcsdk)"
	;;
summit*)
	PKGNAME=sdcsupp
	;;
*)
	PKGNAME=wpa_supplicant
	;;
esac

[ -n "${VERSION}" ] && RELEASE_SUFFIX="-${VERSION}"
RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}${RELEASE_SUFFIX}.tar"

sed -nE "s/^${PKGNAME},\.\///p" "${BUILD_DIR}/packages-file-list.txt" |\
	tar -cf "${RELEASE_FILE}" -C "${TARGET_DIR}" -T -

case "${BR2_LRD_PRODUCT}" in
*legacy*)
	tar -uf "${RELEASE_FILE}" -C "${STAGING_DIR}" \
		--owner=0 --group=0 --numeric-owner \
		usr/include/sdc_sdk.h \
		usr/include/sdc_events.h \
		usr/include/lrd_sdk_pil.h \
		usr/include/lrd_sdk_eni.h \
		usr/lib/libsdc_sdk.so
	;;
*libs*)
	;;
*)
	tar -uf "${RELEASE_FILE}" -C "${STAGING_DIR}" \
		--owner=0 --group=0 --numeric-owner \
		usr/include/wpa_ctrl.h
	;;
esac

bzip2 -f "${RELEASE_FILE}"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: done."
