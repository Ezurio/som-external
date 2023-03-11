#
# post_image_secure.sh
#
# Generate all secure NAND and SWU artifacts
#
# Inputs - must be located in BINARIES_DIR:
#
#	keys/dev.key			Kernel & SWU signing private key
#	keys/dev.crt			Kernel 7 SWU signing public key
#	keys/key.bin			U-Boot symmetric encryption key
#	boot.scr			Kernel boot script template
#	u-boot-spl.dtb			U-Boot SPL FDT
#	u-boot.its			U-Boot FIT image script
#	u-boot.dtb			U-Boot FDT
#	kernel.its			Kernel FIT image descriptor
#	zImage				Kernel
#	at91-??.dtb			Kernel FDT
#	rootfs.squashfs			RootFS
#	$SWU_FILES			Files to store in .swu
#	sw-description (optional)	Partial SWU generation script
#	sw-description-full (optional)	Full SWU generation script
#
# Secured artifacts generated in BINARIES_DIR:
#
#	boot.bin			U-Boot SPL
#	u-boot.itb			U-Boot FIT (encrypted)
#	kernel.itb			Kernel FIT (signed)
#	${BR2_LRD_PRODUCT}.swu		Partial SWU (signed)
#	${BR2_LRD_PRODUCT}-full.swu	Full SWU (signed)
#

echo "${BR2_LRD_PRODUCT^^} POST IMAGE SECURE script: starting..."

BOARD_DIR="${1}"
SWU_FILES="${2}"
SWUPDATE_SIG="${3}"
SD=${4:=false}

# enable tracing and exit on errors
set -x -e

# Secure tooling checks
mkimage=${BUILD_DIR}/uboot-custom/tools/mkimage
atmel_pmecc_params=${BUILD_DIR}/uboot-custom/tools/atmel_pmecc_params
openssl=${HOST_DIR}/usr/bin/openssl
veritysetup=${HOST_DIR}/sbin/veritysetup

die() { echo "$@" >&2; exit 1; }

grep -q SALT ${BINARIES_DIR}/boot.scr && SECURE_ROOTFS=true || SECURE_ROOTFS=false

[ -x ${mkimage} ] || \
	die "No mkimage found (uboot has not been built?)"
[ -x ${openssl} ] || \
	die "no openssl found (host-openssl has not been built?)"

if ! ${SD} ; then
[ -x ${atmel_pmecc_params} ] || \
	die "no atmel_pmecc_params found (uboot has not been built?)"
fi

if ${SECURE_ROOTFS} ; then
[ -x ${veritysetup} ] || \
	die "No veritysetup found (host-cryptsetup has not been built?)"
fi

echo "# entering ${BINARIES_DIR} for this script"
cd ${BINARIES_DIR}

# Create keys if not present
if [ ! -f keys/dev.key ]; then
	${openssl} genrsa -out keys/dev.key 2048
	${openssl} req -batch -new -x509 -key keys/dev.key -out keys/dev.crt
	# Create random key, for AES128, key is 16 bytes long
	dd if=/dev/random of=keys/key.bin bs=16 count=1
	# Create random IV, AES block is 16 bytes, regardless of key size
	dd if=/dev/random of=keys/key-iv.bin bs=16 count=1
fi

# Create unsecured_images dir and copy off unsigned images
mkdir -p unsecured_images
cp -ft unsecured_images u-boot.dtb u-boot-spl.dtb

# Backup kernel boot script (with no verity hash) for release artifacts
cp -f boot.scr boot.scr.nohash

# Check if we are creating secure rootfs
if ${SECURE_ROOTFS} ; then
	# Generate the hash table for squashfs
	rm -f $rootfs.verity
	${veritysetup} format rootfs.squashfs rootfs.verity > rootfs.verity.header
	# Get the root hash
	HASH="$(awk '/Root hash:/ {print $3}' rootfs.verity.header)"
	SALT="$(awk '/Salt:/ {print $2}' rootfs.verity.header)"
	BLOCKS="$(awk '/Data blocks:/ {print $3}' rootfs.verity.header)"
	SIZE=$((${BLOCKS} * 8))
	OFFSET=$((${BLOCKS} + 1))

	# Generate a combined rootfs
	cat rootfs.squashfs rootfs.verity > rootfs.bin

	# Generate the kernel boot script
	sed -i -e "s/SALT/${SALT}/g" -e "s/HASH/${HASH}/g" -e "s/BLOCKS/${BLOCKS}/g" -e "s/SIZE/${SIZE}/g" -e "s/OFFSET/${OFFSET}/g" boot.scr
fi

# Create Kernel FIT image, and store signature in u-boot
${mkimage} -f kernel.its kernel-nosig.itb
${mkimage} -f kernel.its -F -K u-boot.dtb -k keys -r kernel.itb

# Create U-Boot FIT image (encrypted), and store key, IV and signature in SPL
${mkimage} -f u-boot.its -F -K u-boot-spl.dtb -k keys -r u-boot.itb

# Create final SPL FIT with appended keyed DTB
cat u-boot-spl-nodtb.bin u-boot-spl.dtb > u-boot-spl.bin

if ${SD} ; then
	${mkimage} -T atmelimage -d ${BINARIES_DIR}/u-boot-spl.bin ${BINARIES_DIR}/boot.bin
else
	# Generate Atmel PMECC boot.bin from SPL
	${mkimage} -T atmelimage -n $(${atmel_pmecc_params}) -d u-boot-spl.bin boot.bin
	# Save off the raw PMECC header
	dd if=boot.bin of=pmecc.bin bs=208 count=1
fi

# Restore unsecured components
mv -ft ./ unsecured_images/*
rm -rf unsecured_images/
mv -f boot.scr.nohash boot.scr

[ -f sw-description ] && have_swdesc=true || have_swdesc=false
[ -f sw-description-full ] && have_swdescf=true || have_swdescf=false

# Backup incoming sw-description* and restore prior to exit
# Caller needs unprocessed versions for further use
${have_swdesc} && cp sw-description sw-description-saved
${have_swdescf} && cp sw-description-full sw-description-full-saved

# Embed component hashes in SWU scripts
for i in ${SWU_FILES/sw-description /}
do
	sha_value=$(sha256sum $i | awk '{print $1}')
	component_sha="@${i}.sha256"
	echo "${i}          ${sha_value}"

	${have_swdesc} && \
		sed -i -e "s/${component_sha}/${sha_value}/g" sw-description

	${have_swdescf} && \
		sed -i -e "s/${component_sha}/${sha_value}/g" sw-description-full

	if [ "${i}" = rootfs.bin ] || [ "${i}" = kernel.itb ]; then
		md5_value=$(md5sum $i | awk '{print $1}')
		component_md5sum="@${i}.md5sum"
		echo "${i}          ${md5_value}"

		${have_swdesc} && \
			sed -i -e "s/${component_md5sum}/${md5_value}/g" sw-description

		${have_swdescf} && \
			sed -i -e "s/${component_md5sum}/${md5_value}/g" sw-description-full
	fi
done

if [ -n "${SWUPDATE_SIG}" ]; then
	ALL_SWU_FILES="${SWU_FILES/sw-description/sw-description sw-description.sig}"
else
	ALL_SWU_FILES="${SWU_FILES}"
fi
SWU_FILE_STR="${ALL_SWU_FILES// /\\n}"

# Generate partial SWU (no bootloaders)
if ${have_swdesc} ; then
	case "${SWUPDATE_SIG}" in
	cms)
		${openssl} cms -sign -in sw-description -out sw-description.sig \
			-signer keys/dev.crt -inkey keys/dev.key -outform DER -nosmimecap -binary
		;;

	rawrsa)
		${openssl} dgst -sha256 -sign keys/dev.key sw-description > sw-description.sig
		;;
	esac

	echo -e "${SWU_FILE_STR}" | cpio -ovL -H crc > ${BR2_LRD_PRODUCT}.swu
	rm -f sw-description.sig
fi

# Generate full SWU (with bootloaders)
if ${have_swdescf} ; then
	mv -f sw-description-full sw-description

	case "${SWUPDATE_SIG}" in
	cms)
		${openssl} cms -sign -in sw-description -out sw-description.sig \
			-signer keys/dev.crt -inkey keys/dev.key -outform DER -nosmimecap -binary
		;;

	rawrsa)
		${openssl} dgst -sha256 -sign keys/dev.key sw-description > sw-description.sig
		;;
	esac

	echo -e "${SWU_FILE_STR}" | cpio -ovL -H crc > ${BR2_LRD_PRODUCT}-full.swu
	rm -f sw-description.sig
fi

${have_swdesc} && mv -f sw-description-saved sw-description
${have_swdescf} && mv -f sw-description-full-saved sw-description-full

cd -

echo "${BR2_LRD_PRODUCT^^} POST IMAGE SECURE script: done."
