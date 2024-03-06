BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: starting..."

# enable tracing and exit on errors
set -x -e

mkdir -p ${BINARIES_DIR}

[ -n "${VERSION}" ] && RELEASE_SUFFIX="-${VERSION}"
RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}${RELEASE_SUFFIX}.tar"

tar  -rf "${RELEASE_FILE}" -C "${TARGET_DIR}" \
	--owner=root --group=root \
	./usr/lib/ossl-modules/fips.so

bzip2 -f "${RELEASE_FILE}"

if [ "${BR2_LRD_DEVEL_BUILD}" == "y" ]; then
	[ -z "${BR2_DL_DIR}" ] && \
		BR2_DL_DIR="$(sed -n 's,^BR2_DL_DIR="\(.*\)"$,\1,p' ${BR2_CONFIG})"

	if [ -n "${BR2_DL_DIR}" ]; then
		mkdir -p ${BR2_DL_DIR}/${summitssl_fips_provider}
		cp ${RELEASE_FILE}.bz2 \
			${BR2_DL_DIR}/${summitssl_fips_provider}/${BR2_LRD_PRODUCT}-0.${BR2_LRD_BRANCH}.0.0.tar.bz2
	fi
fi

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: done."
