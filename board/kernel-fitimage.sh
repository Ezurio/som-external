#! /bin/sh

fitimage_set_vars() {
	# Description string
	FIT_DESC="Summit Linux fitImage for ${BR2_SUMMIT_PRODUCT}"

	UBOOT_MKIMAGE_KERNEL_TYPE=${UBOOT_MKIMAGE_KERNEL_TYPE:-"kernel"}
	UBOOT_ARCH=${UBOOT_ARCH:-"arm64"}
	# load address for kernel
	UBOOT_LOADADDRESS=${UBOOT_LOADADDRESS:-"0x40400000"}
	UBOOT_ENTRYPOINT=${UBOOT_ENTRYPOINT:-"0x40400000"}

	# Kernel fitImage Hash Algo
	FIT_HASH_ALG=${FIT_HASH_ALG:-"sha256"}

	# Kernel fitImage Signature Algo
	FIT_SIGN_ALG=${FIT_SIGN_ALG:-"rsa2048"}

	# Kernel / U-Boot fitImage Padding Algo
	FIT_PAD_ALG=${FIT_PAD_ALG:-"pkcs-1.5"}

	# Size of private keys in number of bits
	FIT_SIGN_NUMBITS=${FIT_SIGN_NUMBITS:-"2048"}

	# args to openssl genrsa (Default is just the public exponent)
	FIT_KEY_GENRSA_ARGS=${FIT_KEY_GENRSA_ARGS:-"-F4"}

	# Standard format for public key certificate
	FIT_KEY_SIGN_PKCS=${FIT_KEY_SIGN_PKCS:-"-x509"}

	# Sign individual images as well
	FIT_SIGN_INDIVIDUAL=${FIT_SIGN_INDIVIDUAL:-"0"}

	UBOOT_ENCRYPT_ENABLE=${UBOOT_ENCRYPT_ENABLE:-"0"}

	FIT_CONF_PREFIX=${FIT_CONF_PREFIX:-"conf-"}

	# FIT_CONF_PREFIX[doc] = "Prefix to use for FIT configuration node name"

	FIT_SUPPORTED_INITRAMFS_FSTYPES=${FIT_SUPPORTED_INITRAMFS_FSTYPES:-"cpio.lz4 cpio.lzo cpio.lzma cpio.xz cpio.zst cpio.gz ext2.gz cpio"}

	# Allow user to select the default DTB for FIT image when multiple dtb's exists.
	FIT_CONF_DEFAULT_DTB=${FIT_CONF_DEFAULT_DTB:-""}
}

# Keys used to sign individually image nodes.
# The keys to sign image nodes must be different from those used to sign
# configuration nodes, otherwise the "required" property, from
# UBOOT_DTB_BINARY, will be set to "conf", because "conf" prevails on "image".
# Then the images signature checking will not be mandatory and no error will be
# raised in case of failure.
# UBOOT_SIGN_IMG_KEYNAME = "dev2" # keys name in keydir (eg. "dev2.crt", "dev2.key")

#
# Emit the fitImage ITS header
#
# $1 ... .its filename
fitimage_emit_fit_header() {
	cat << EOF >> "${1}"
/dts-v1/;

/ {
	description = "${FIT_DESC}";
EOF
}

#
# Emit the fitImage section bits
#
# $1 ... .its filename
# $2 ... Section bit type: imagestart - image section start
#                          confstart  - configuration section start
#                          sectend    - section end
#                          fitend     - fitimage end
#
fitimage_emit_section_maint() {
	case ${2} in
	imagestart)
	cat << EOF >> "${1}"

	images {
EOF
	;;
	confstart)
	cat << EOF >> "${1}"

	configurations {
EOF
	;;
	sectend)
	cat << EOF >> "${1}"
	};
EOF
	;;
	fitend)
	cat << EOF >> "${1}"
};
EOF
	;;

	compend)
	cat << EOF >> "${1}"
		};
EOF
	;;
	esac
}

#
# Emit the fitImage ITS kernel section
#
# $1 ... .its filename
# $2 ... Image counter
# $3 ... Path to kernel image
# $4 ... Compression type
fitimage_emit_section_kernel() {

	kernel_csum="${FIT_HASH_ALG}"
	kernel_sign_algo="${FIT_SIGN_ALG}"
	kernel_sign_keyname="${UBOOT_SIGN_IMG_KEYNAME}"
	kernel_padding_algo="${FIT_PAD_ALG}"

	ENTRYPOINT="${UBOOT_ENTRYPOINT}"
	if [ -n "${UBOOT_ENTRYSYMBOL}" ]; then
		ENTRYPOINT=$("${HOST_PREFIX}nm" vmlinux | \
			awk '$3=="${UBOOT_ENTRYSYMBOL}" {print "0x"${1};exit}')
	fi

	cat << EOF >> "${1}"
		kernel-${2} {
			description = "Linux kernel";
			data = /incbin/("${3}");
			type = "${UBOOT_MKIMAGE_KERNEL_TYPE}";
			arch = "${UBOOT_ARCH}";
			os = "linux";
			compression = "${4}";
			summit-version = "${FIT_SUMMIT_VERSION}";
			load = <${UBOOT_LOADADDRESS}>;
			entry = <${ENTRYPOINT}>;

			hash-1 {
				algo = "${kernel_csum}";
			};
EOF
	if [ "${UBOOT_ENCRYPT_ENABLE}" = "1" ]; then
		cat << EOF >> "${1}"

			cipher {
				algo = "${FIT_ENCRYPT_ALGO}";
				key-name-hint = "${UBOOT_ENCRYPT_KEYNAME}";
				iv-name-hint = "${UBOOT_ENCRYPT_IVNAME}";
			};
EOF
	fi
	if [ "${UBOOT_SIGN_ENABLE}" = "1" ] && [ "${FIT_SIGN_INDIVIDUAL}" = "1" ] && [ -n "${kernel_sign_keyname}" ] ; then
		cat << EOF >> "${1}"

			signature-1 {
				algo = "${kernel_csum},${kernel_sign_algo}";
				key-name-hint = "${kernel_sign_keyname}";
				padding = "${kernel_padding_algo}";
			};
EOF
	fi

	fitimage_emit_section_maint "${1}" compend
}

#
# Emit the fitImage ITS DTB section
#
# $1 ... .its filename
# $2 ... Image counter
# $3 ... Path to DTB image
fitimage_emit_section_dtb() {

	dtb_csum="${FIT_HASH_ALG}"
	dtb_sign_algo="${FIT_SIGN_ALG}"
	dtb_sign_keyname="${UBOOT_SIGN_IMG_KEYNAME}"
	dtb_padding_algo="${FIT_PAD_ALG}"

	dtb_loadline=""
	if [ "${3##*.}" = "dtbo" ]; then
		if [ -n "${UBOOT_DTBO_LOADADDRESS}" ]; then
			dtb_loadline="load = <${UBOOT_DTBO_LOADADDRESS}>;"
		fi
	elif [ -n "${UBOOT_DTB_LOADADDRESS}" ]; then
		dtb_loadline="load = <${UBOOT_DTB_LOADADDRESS}>;"
	elif [ -n "${FDT_LOADADDRESS}" ]; then
		dtb_loadline="load = <${FDT_LOADADDRESS}>;"
	fi
	cat << EOF >> "${1}"
		fdt-$2 {
			description = "Flattened Device Tree blob";
			data = /incbin/("$3");
			type = "flat_dt";
			arch = "${UBOOT_ARCH}";
			compression = "none";
			${dtb_loadline}

			hash-1 {
				algo = "${dtb_csum}";
			};
EOF
	if [ "${UBOOT_ENCRYPT_ENABLE}" = "1" ]; then
		cat << EOF >> "${1}"

			cipher {
				algo = "${FIT_ENCRYPT_ALGO}";
				key-name-hint = "${UBOOT_ENCRYPT_KEYNAME}";
				iv-name-hint = "${UBOOT_ENCRYPT_IVNAME}";
			};
EOF
	fi
	if [ "${UBOOT_SIGN_ENABLE}" = "1" ] && [ "${FIT_SIGN_INDIVIDUAL}" = "1" ] && [ -n "${dtb_sign_keyname}" ] ; then
		cat << EOF >> "${1}"

			signature-1 {
				algo = "${dtb_csum},${dtb_sign_algo}";
				key-name-hint = "${dtb_sign_keyname}";
				padding = "${dtb_padding_algo}";
			};
EOF
	fi

	fitimage_emit_section_maint "${1}" compend
}

#
# Emit the fitImage ITS u-boot script section
#
# $1 ... .its filename
# $2 ... Image counter
# $3 ... Path to boot script image
fitimage_emit_section_boot_script() {

	bootscr_csum="${FIT_HASH_ALG}"
	bootscr_sign_algo="${FIT_SIGN_ALG}"
	bootscr_sign_keyname="${UBOOT_SIGN_IMG_KEYNAME}"
	bootscr_padding_algo="${FIT_PAD_ALG}"

	cat << EOF >> "${1}"
		script {
			description = "Boot Script";
			data = /incbin/("$3");
			type = "script";
			arch = "${UBOOT_ARCH}";
			compression = "none";

			hash-1 {
				algo = "${bootscr_csum}";
			};
EOF
	if [ "${UBOOT_ENCRYPT_ENABLE}" = "1" ]; then
		cat << EOF >> "${1}"
			cipher {
				algo = "${FIT_ENCRYPT_ALGO}";
				key-name-hint = "${UBOOT_ENCRYPT_KEYNAME}";
				iv-name-hint = "${UBOOT_ENCRYPT_IVNAME}";
			};
EOF
	fi
	if [ "${UBOOT_SIGN_ENABLE}" = "1" ] && [ "${FIT_SIGN_INDIVIDUAL}" = "1" ] && [ -n "${bootscr_sign_keyname}" ] ; then
		cat << EOF >> "${1}"

			signature-1 {
				algo = "${bootscr_csum},${bootscr_sign_algo}";
				key-name-hint = "${bootscr_sign_keyname}";
				padding = "${bootscr_padding_algo}";
			};
EOF
	fi

	fitimage_emit_section_maint "${1}" compend
}

#
# Emit the fitImage ITS ramdisk section
#
# $1 ... .its filename
# $2 ... Image counter
# $3 ... Path to ramdisk image
fitimage_emit_section_ramdisk() {

	ramdisk_csum="${FIT_HASH_ALG}"
	ramdisk_sign_algo="${FIT_SIGN_ALG}"
	ramdisk_sign_keyname="${UBOOT_SIGN_IMG_KEYNAME}"
	ramdisk_padding_algo="${FIT_PAD_ALG}"
	ramdisk_loadline=""
	ramdisk_entryline=""

	if [ -n "${UBOOT_RD_LOADADDRESS}" ]; then
		ramdisk_loadline="load = <${UBOOT_RD_LOADADDRESS}>;"
	fi
	if [ -n "${UBOOT_RD_ENTRYPOINT}" ]; then
		ramdisk_entryline="entry = <${UBOOT_RD_ENTRYPOINT}>;"
	fi

	cat << EOF >> "${1}"
		ramdisk-${2} {
			description = "${INITRAMFS_IMAGE}";
			data = /incbin/("${3}");
			type = "ramdisk";
			arch = "${UBOOT_ARCH}";
			os = "linux";
			compression = "none";
			${ramdisk_loadline}
			${ramdisk_entryline}

			hash-1 {
				algo = "${ramdisk_csum}";
			};
EOF
	if [ "${UBOOT_ENCRYPT_ENABLE}" = "1" ]; then
		cat << EOF >> "${1}"

			cipher {
				algo = "${FIT_ENCRYPT_ALGO}";
				key-name-hint = "${UBOOT_ENCRYPT_KEYNAME}";
				iv-name-hint = "${UBOOT_ENCRYPT_IVNAME}";
			};
EOF
	fi
	if [ "${UBOOT_SIGN_ENABLE}" = "1" ] && [ "${FIT_SIGN_INDIVIDUAL}" = "1" ] && [ -n "${ramdisk_sign_keyname}" ] ; then
		cat << EOF >> "${1}"

			signature-1 {
				algo = "${ramdisk_csum},${ramdisk_sign_algo}";
				key-name-hint = "${ramdisk_sign_keyname}";
				padding = "${ramdisk_padding_algo}";
			};
EOF
	fi

	fitimage_emit_section_maint "${1}" compend
}

#
# Emit the fitImage ITS configuration section
#
# $1 ... .its filename
# $2 ... Linux kernel ID
# $3 ... DTB image name
# $4 ... ramdisk ID
# $5 ... u-boot script ID
# $6 ... config ID
# $7 ... default flag
fitimage_emit_section_config() {

	conf_csum="${FIT_HASH_ALG}"
	conf_sign_algo="${FIT_SIGN_ALG}"
	conf_padding_algo="${FIT_PAD_ALG}"
	if [ "${UBOOT_SIGN_ENABLE}" = "1" ] ; then
		conf_sign_keyname="${UBOOT_SIGN_KEYNAME}"
	fi

	its_file="${1}"
	kernel_id="${2}"
	dtb_image="${3}"
	ramdisk_id="${4}"
	bootscr_id="${5}"
	config_id="${6}"

	# Test if we have any DTBs at all
	sep=""
	conf_desc=""
	conf_node="${FIT_CONF_PREFIX}"
	kernel_line=""
	fdt_line=""
	ramdisk_line=""
	bootscr_line=""
	setup_line=""

	# conf node name is selected based on dtb ID if it is present,
	# otherwise its selected based on kernel ID
	if [ -n "${dtb_image}" ]; then
		conf_node=${conf_node}${dtb_image}
	else
		conf_node=${conf_node}${kernel_id}
	fi

	if [ -n "${kernel_id}" ]; then
		conf_desc="Summit Linux Kernel"
		sep=", "
		kernel_line="kernel = \"kernel-${kernel_id}\";"
	fi

	if [ -n "${dtb_image}" ]; then
		conf_desc="${conf_desc}${sep}FDT blob"
		sep=", "
		fdt_line="fdt = \"fdt-${dtb_image}\";"
	fi

	if [ -n "${ramdisk_id}" ]; then
		conf_desc="${conf_desc}${sep}ramdisk"
		sep=", "
		ramdisk_line="ramdisk = \"ramdisk-$ramdisk_id\";"
	fi

	if [ -n "${bootscr_id}" ]; then
		conf_desc="${conf_desc}${sep}u-boot script"
		sep=", "
		bootscr_line="script = \"script\";"
	fi

	if [ -n "${config_id}" ]; then
		conf_desc="${conf_desc}${sep}setup"
		setup_line="setup = \"setup-${config_id}\";"
	fi

	cat << EOF >> "${its_file}"
		${conf_node} {
			description = "${conf_desc}";
			${kernel_line}
			${fdt_line}
			${bootscr_line}
			${ramdisk_line}
			${setup_line}
EOF

	if [ -n "${conf_sign_keyname}" ] ; then

		sign_line="sign-images = "
		sep=""

		if [ -n "${kernel_id}" ]; then
			sign_line="${sign_line}${sep}\"kernel\""
			sep=", "
		fi

		if [ -n "${dtb_image}" ]; then
			sign_line="${sign_line}${sep}\"fdt\""
			sep=", "
		fi

		if [ -n "${ramdisk_id}" ]; then
			sign_line="${sign_line}${sep}\"ramdisk\""
			sep=", "
		fi

		if [ -n "${bootscr_id}" ]; then
			sign_line="${sign_line}${sep}\"script\""
			sep=", "
		fi

		if [ -n "${config_id}" ]; then
			sign_line="${sign_line}${sep}\"setup\""
		fi

		sign_line="${sign_line};"

		cat << EOF >> "${its_file}"

			signature-1 {
				algo = "${conf_csum},${conf_sign_algo}";
				key-name-hint = "${conf_sign_keyname}";
				padding = "${conf_padding_algo}";
				${sign_line}
			};
EOF
	fi

	fitimage_emit_section_maint "${1}" compend
}

#
# Assemble fitImage
#
# $1 ... .its filename
# $2 ... fitImage name
# $3 ... include ramdisk
fitimage_assemble() {
	fitimage_set_vars

	kernelcount=1
	DTBS=""
	ramdiskcount=${3}
	setupcount=""

	rm -f "${1}"

	if [ -n "${UBOOT_SIGN_IMG_KEYNAME}" ] && [ "${UBOOT_SIGN_KEYNAME}" = "${UBOOT_SIGN_IMG_KEYNAME}" ]; then
		die "Keys used to sign images and configuration nodes must be different."
	fi

	fitimage_emit_fit_header "${1}"

	#
	# Step 1: Prepare a kernel image section.
	#
	fitimage_emit_section_maint "${1}" imagestart

	fitimage_emit_section_kernel "${1}" ${kernelcount} "${KERNEL_IMAGE}" "${linux_comp:-}"

	#
	# Step 2: Prepare a DTB image section
	#
	# Split .dtb and .dtbo files
	for DTB in ${KERNEL_DEVICETREE}; do
		DTB=${DTB##*/}
		case ${DTB} in
			*.dtbo)
				DTBOS="${DTBOS} ${DTB}"
				;;
			*.dtb)
				DTBS="${DTBS} ${DTB}"
				;;
		esac
	done

	# Add .dtb files to image section
	for DTB in ${DTBS}; do
		fitimage_emit_section_dtb "${1}" "${DTB}" "${DTB}"
	done

	# Add .dtbo files to image section
	for DTBO in ${DTBOS}; do
		fitimage_emit_section_dtb "${1}" "${DTBO}" "${DTBO}"
	done

	#
	# Step 3: Prepare a u-boot script section
	#
	if [ -n "${UBOOT_SCRIPT}" ]; then
		bootscr_id="1"
		fitimage_emit_section_boot_script "${1}" "${bootscr_id}" "${UBOOT_SCRIPT}"
	fi

	#
	# Step 5: Prepare a ramdisk section.
	#
	if [ "${ramdiskcount}" = "1" ] && [ "${INITRAMFS_IMAGE_BUNDLE}" != "1" ]; then
		# Find and use the first initramfs image archive type we find
		found=
		for img in ${FIT_SUPPORTED_INITRAMFS_FSTYPES}; do
			initramfs_path="${DEPLOY_DIR_IMAGE}/${INITRAMFS_IMAGE_NAME}.$img"
			if [ -e "${initramfs_path}" ]; then
				echo "Found initramfs image: ${initramfs_path}"
				found=true
				fitimage_emit_section_ramdisk "${1}" "${ramdiskcount}" "${initramfs_path}"
				break
			else
				echo "Did not find initramfs image: ${initramfs_path}"
			fi
		done

		if [ -z "$found" ]; then
			die "Could not find a valid initramfs type for ${INITRAMFS_IMAGE_NAME}, the supported types are: ${FIT_SUPPORTED_INITRAMFS_FSTYPES}"
		fi
	fi

	fitimage_emit_section_maint "${1}" sectend

	#
	# Step 6: Prepare a configurations section
	#
	fitimage_emit_section_maint "${1}" confstart

	if [ -n "${DTBS}" ]; then
		echo "		default = \"${FIT_CONF_PREFIX}${FIT_CONF_DEFAULT_DTB:-${DTBS##* }}\";" >> "${1}"
		for DTB in ${DTBS}; do
			fitimage_emit_section_config "${1}" ${kernelcount} "${DTB}" "${ramdiskcount}" "${bootscr_id}" "${setupcount}"
		done

		for DTBO in ${DTBOS}; do
			fitimage_emit_section_config "${1}" "" "${DTBO}" "" "" ""
		done
	else
		echo "		default = \"${FIT_CONF_PREFIX}${kernelcount}\";" >> "${1}"
		fitimage_emit_section_config "${1}" ${kernelcount} "" "${ramdiskcount}" "${bootscr_id}"  "${setupcount}"
	fi

	fitimage_emit_section_maint "${1}" sectend

	fitimage_emit_section_maint "${1}" fitend

	sed -r -i '/^\s+$/d' "${1}"
}

fitimage_assemble "${1}"
