# enable tracing and exit on errors
set -x -e

BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: starting..."

if [ -f ${TARGET_DIR}/usr/lib/libedit.so ]; then
LIBEDIT=$(readlink ${TARGET_DIR}/usr/lib/libedit.so)
LIBEDITLRD=${LIBEDIT/libedit./libedit.lrd.}
cp "${TARGET_DIR}/usr/lib/${LIBEDIT}" "${TARGET_DIR}/usr/lib/${LIBEDITLRD}"
fi

if [ -f ${TARGET_DIR}/usr/lib/libncurses.so ]; then
LIBNCURSES=$(readlink ${TARGET_DIR}/usr/lib/libncurses.so)
LIBNCURSESLRD=${LIBNCURSES/libncurses./libncurses.lrd.}
cp "${TARGET_DIR}/usr/lib/${LIBNCURSES}" "${TARGET_DIR}/usr/lib/${LIBNCURSESLRD}"
fi

add_file() {
	local name=${1}
	shift
	for var in "${@}"; do
		[ -f "${TARGET_DIR}${var}" ] && \
			echo ${var} >> "${TARGET_DIR}/${name}.manifest"
	done
}

add_firmware() {
	add_file ${1} $(ls ${2} | sed "s,^${TARGET_DIR},,")
}

rm -f ${TARGET_DIR}/*.manifest

case "${BR2_LRD_PRODUCT}" in
mfg60*)
	#lrt and other vendor mfg tools are mutually exclusive
	[ -f ${TARGET_DIR}/usr/bin/lrt ] &&  exit 0

	add_file ${BR2_LRD_PRODUCT} \
		/usr/bin/lmu \
		/usr/bin/lru \
		/usr/bin/btlru \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${BR2_LRD_PRODUCT} "${TARGET_DIR}/lib/firmware/lrdmwl/88W8997_mfg_*"
	;;

reg45*)
	# move tcmd.sh into package
	cp ${BR2_EXTERNAL_LRD_SOM_PATH}/board/mfg-reg/rootfs-additions/tcmd.sh ${TARGET_DIR}/usr/bin

	add_file ${BR2_LRD_PRODUCT} \
		/usr/bin/lru \
		/usr/sbin/smu_cli \
		/usr/bin/tcmd.sh \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${BR2_LRD_PRODUCT} "${TARGET_DIR}/lib/firmware/ath6k/AR6003/hw2.1.1/athtcmd*"
	;;

reg50*)
	# move tcmd.sh into package
	cp ${BR2_EXTERNAL_LRD_SOM_PATH}/board/mfg-reg/rootfs-additions/tcmd.sh ${TARGET_DIR}/usr/bin

	add_file ${BR2_LRD_PRODUCT} \
		/usr/bin/lru \
		/usr/sbin/smu_cli \
		/usr/bin/tcmd.sh \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${BR2_LRD_PRODUCT} "${TARGET_DIR}/lib/firmware/ath6k/AR6004/hw3.0/utf*"
	;;

regLWB*)
	if [ -f ${TARGET_DIR}/usr/bin/wl ]; then
		lwbname=${BR2_LRD_PRODUCT/regLWB/regCypress}
		add_file ${lwbname} /usr/bin/wl
		add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/brcm/brcmfmac4339-sdio-mfg_*.bin"
		add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/brcm/brcmfmac43430-sdio-mfg_*.bin"
	fi

	lwbname=${BR2_LRD_PRODUCT/regLWB/regLWB5plus}
	add_file ${lwbname} \
		/usr/bin/lru \
		/usr/bin/btlru \
		/lib/firmware/brcm/brcmfmac4373-div-mfg.txt \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/brcm/brcmfmac4373-*-mfg_*.bin"

	lwbname=${BR2_LRD_PRODUCT/regLWB/regLWBplus}
	add_file ${lwbname} \
		/usr/bin/lru \
		/usr/bin/btlru \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/brcm/brcmfmac43439-sdio-mfg_*.bin"

	lwbname=${BR2_LRD_PRODUCT/regLWB/regLWB6}
	add_file ${lwbname} \
		/usr/bin/lru \
		/usr/bin/btlru \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/cypress/cyfmac55572-*-mfg_*.trxse"

	lwbname=${BR2_LRD_PRODUCT/regLWB/regSONA}
	add_file ${lwbname} \
		/usr/bin/lru \
		/usr/bin/btlru \
		/usr/lib/${LIBEDITLRD} \
		/usr/lib/${LIBNCURSESLRD}

	add_firmware ${lwbname} "${TARGET_DIR}/lib/firmware/cypress/cyfmac55500-sdio-mfg_*.trxse"
	;;

*)
	exit 1
	;;
esac

# make sure board script is not in target directory and copy it from rootfs-additions
cp ${BR2_EXTERNAL_LRD_SOM_PATH}/board/mfg-reg/rootfs-additions/reg_tools.sh ${TARGET_DIR}

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: done."
