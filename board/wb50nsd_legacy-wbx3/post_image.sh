# enable tracing and exit on errors
set -x -e

[ -n "${BR2_LRD_PRODUCT}" ] || \
	export BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: starting..."

# Tooling checks
mkimage=${BUILD_DIR}/uboot-custom/tools/mkimage
mkenvimage=${BUILD_DIR}/uboot-custom/tools/mkenvimage

die() { echo "$@" >&2; exit 1; }

[ -x ${mkimage} ] || \
	die "No mkimage found (uboot has not been built?)"
[ -x ${mkenvimage} ] || \
	die "No mkenvimage found (uboot has not been built?)"

(cd "${BINARIES_DIR}" && "${mkimage}" -f u-boot.scr.its u-boot.scr.itb) || exit 1

${mkenvimage} -p 0 -s 131072 -o ${BINARIES_DIR}/uboot.env ${BINARIES_DIR}/u-boot-initial-env

echo "# entering ${BINARIES_DIR} for the next command"

(cd ${BINARIES_DIR} && ${mkimage} -f u-boot.its u-boot.itb) || exit 1
cat "${BINARIES_DIR}/u-boot-spl-nodtb.bin" "${BINARIES_DIR}/u-boot-spl.dtb" > "${BINARIES_DIR}/u-boot-spl.bin"

${mkimage} -T atmelimage -d ${BINARIES_DIR}/u-boot-spl.bin ${BINARIES_DIR}/boot.bin

size_check () {
	[ $(stat -Lc "%s" ${BINARIES_DIR}/${1}) -le $((${2}*128*1024)) ] || \
		{ echo "${1} size exceeded ${2} block limit, failed"; exit 1; }
}

if [ -n "${VERSION}" ]; then
	RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird-${VERSION}.tar"
else
	RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird.tar"
fi

tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
	--owner=root --group=root \
	uboot.env mksdcard.sh mksdimg.sh boot.bin u-boot.itb

bzip2 -f ${RELEASE_FILE}

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: done."
