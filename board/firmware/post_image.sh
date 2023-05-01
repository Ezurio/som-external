BR2_LRD_PRODUCT=firmware
BOARD_DIR="$(realpath $(dirname $0))"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: starting..."

# enable tracing and exit on errors
set -x -e

mkdir -p ${BINARIES_DIR}

FW_DIR="${TARGET_DIR}/lib/firmware"

[ -n "${VERSION}" ] && RELEASE_SUFFIX="-${VERSION}"

create_bcm4343w_firmware_archive()
{
	local DOMAIN=${1}

	local BRCM_DIR=${FW_DIR}/brcm

	ln -rsf ${BRCM_DIR}/brcmfmac43430-sdio-${DOMAIN}.txt ${BRCM_DIR}/brcmfmac43430-sdio.txt

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-lwb-${DOMAIN}-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/BCM43430A1.hcd \
		lib/firmware/brcm/BCM43430A1_*.hcd \
		lib/firmware/brcm/brcmfmac43430-sdio.bin \
		lib/firmware/brcm/brcmfmac43430-sdio.clm_blob \
		lib/firmware/brcm/brcmfmac43430-sdio-${DOMAIN}.txt \
		lib/firmware/brcm/brcmfmac43430-sdio-prod*.bin \
		lib/firmware/brcm/brcmfmac43430-sdio.txt \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_bcm4339_firmware_archive()
{
	local DOMAIN=${1}

	local BRCM_DIR=${FW_DIR}/brcm

	ln -rsf ${BRCM_DIR}/brcmfmac4339-sdio-${DOMAIN}.txt ${BRCM_DIR}/brcmfmac4339-sdio.txt

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-lwb5-${DOMAIN}-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/BCM4335C0.hcd \
		lib/firmware/brcm/BCM4335C0_*.hcd \
		lib/firmware/brcm/brcmfmac4339-sdio.bin \
		lib/firmware/brcm/brcmfmac4339-sdio-${DOMAIN}.txt \
		lib/firmware/brcm/brcmfmac4339-sdio-prod*.bin \
		lib/firmware/brcm/brcmfmac4339-sdio.txt \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_bcm43439_firmware_archive()
{
	grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_BCM43439=y" ${BR2_CONFIG} || return

	local BRCM_DIR=${FW_DIR}/brcm

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-lwbplus-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/BCM4343A2.hcd \
		lib/firmware/brcm/BCM4343A2_*.hcd \
		lib/firmware/brcm/brcmfmac43439-sdio.bin \
		lib/firmware/brcm/brcmfmac43439-sdio-prod*.bin \
		lib/firmware/brcm/brcmfmac43439-sdio.txt \
		lib/firmware/brcm/brcmfmac43439-sdio.clm_blob \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_bcm4373_sdio_uart_firmware_archive()
{
	grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_BCM4373_SDIO_${1^^}=y" ${BR2_CONFIG} || return

	local ANTENNA=${2}

	local BRCM_DIR=${FW_DIR}/brcm

	ln -rsf ${BRCM_DIR}/brcmfmac4373-${ANTENNA}.txt ${BRCM_DIR}/brcmfmac4373-sdio.txt
	ln -rsf ${BRCM_DIR}/brcmfmac4373-clm-${ANTENNA}.clm_blob ${BRCM_DIR}/brcmfmac4373-sdio.clm_blob
	ln -rsf ${BRCM_DIR}/BCM4373A0-sdio-${ANTENNA}_*.hcd ${BRCM_DIR}/BCM4373A0.hcd

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-lwb5plus-sdio-${ANTENNA}-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/BCM4373A0-sdio-${ANTENNA}_*.hcd \
		lib/firmware/brcm/BCM4373A0.hcd \
		lib/firmware/brcm/brcmfmac4373-sdio-prod*.bin \
		lib/firmware/brcm/brcmfmac4373-sdio.bin \
		lib/firmware/brcm/brcmfmac4373-${ANTENNA}.txt \
		lib/firmware/brcm/brcmfmac4373-sdio.txt \
		lib/firmware/brcm/brcmfmac4373-clm-${ANTENNA}.clm_blob \
		lib/firmware/brcm/brcmfmac4373-sdio.clm_blob \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_bcm4373_usb_usb_firmware_archive()
{
	grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_BCM4373_USB_${1^^}=y" ${BR2_CONFIG}	|| return

	local ANTENNA=${2}

	local BRCM_DIR=${FW_DIR}/brcm

	ln -rsf ${BRCM_DIR}/brcmfmac4373-usb-${ANTENNA}-prod_*.bin ${BRCM_DIR}/brcmfmac4373.bin
	ln -rsf ${BRCM_DIR}/brcmfmac4373-clm-${ANTENNA}.clm_blob ${BRCM_DIR}/brcmfmac4373.clm_blob
	ln -rsf ${BRCM_DIR}/BCM4373A0-usb-${ANTENNA}_*.hcd ${BRCM_DIR}/BCM4373A0-04b4-640c.hcd

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-lwb5plus-usb-${ANTENNA}-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/BCM4373A0-usb-${ANTENNA}_*.hcd \
		lib/firmware/brcm/BCM4373A0-04b4-640c.hcd \
		lib/firmware/brcm/brcmfmac4373-usb-${ANTENNA}-prod*.bin \
		lib/firmware/brcm/brcmfmac4373.bin \
		lib/firmware/brcm/brcmfmac4373-clm-${ANTENNA}.clm_blob \
		lib/firmware/brcm/brcmfmac4373.clm_blob \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_60_firmware_archive()
{
	grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_LRDMWL_${1^^}_${2^^}_${3^^}=y" ${BR2_CONFIG} || return

	local FW_FILE=$(basename ${FW_DIR}/lrdmwl/88W8997_${1}_${2}_${3}_*.bin)
	FW_PROD=${1^^^}

	ln -rsf ${FW_DIR}/lrdmwl/${FW_FILE} ${FW_DIR}/lrdmwl/88W8997_${2}.bin
	ln -rsf ${FW_DIR}/regulatory_${FW_PROD}.db ${FW_DIR}/regulatory.db
	ln -rsf ${FW_DIR}/lrdmwl/regpwr_60.db ${FW_DIR}/lrdmwl/regpwr.db

	tar -cjf "${BINARIES_DIR}/laird-${FW_PROD}-radio-firmware-${2}-${3}${RELEASE_SUFFIX}.tar.bz2" \
		-C ${TARGET_DIR} \
		--owner=0 --group=0 --numeric-owner \
		lib/firmware/lrdmwl/88W8997_${2}.bin \
		lib/firmware/lrdmwl/${FW_FILE} \
		lib/firmware/lrdmwl/regpwr_60.db lib/firmware/lrdmwl/regpwr.db \
		lib/firmware/regulatory_${FW_PROD}.db lib/firmware/regulatory.db
}

create_60_firmware_archive 60 sdio uart
create_60_firmware_archive 60 sdio sdio
create_60_firmware_archive 60 pcie uart
create_60_firmware_archive 60 pcie usb
create_60_firmware_archive 60 usb uart
create_60_firmware_archive 60 usb usb

if grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_LRDMWL_SOM8MP=y" ${BR2_CONFIG}; then
	ln -rsf ${FW_DIR}/lrdmwl/88W8997_SOM8MP_sdio_uart_*.bin ${FW_DIR}/lrdmwl/88W8997_sdio.bin
	ln -rsf ${FW_DIR}/lrdmwl/88W8997_SOM8MP_pcie_uart_*.bin ${FW_DIR}/lrdmwl/88W8997_pcie.bin
	ln -rsf ${FW_DIR}/regulatory_60.db ${FW_DIR}/regulatory.db
	ln -rsf ${FW_DIR}/lrdmwl/regpwr_som8mp.db ${FW_DIR}/lrdmwl/regpwr.db

	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-som8mp-radio-firmware${RELEASE_SUFFIX}.tar.bz2" \
		--owner=0 --group=0 --numeric-owner \
		lib/firmware/lrdmwl/88W8997_SOM8MP_*.bin \
		lib/firmware/lrdmwl/88W8997_sdio.bin lib/firmware/lrdmwl/88W8997_pcie.bin \
		lib/firmware/lrdmwl/regpwr_som8mp.db lib/firmware/lrdmwl/regpwr.db \
		lib/firmware/regulatory_60.db lib/firmware/regulatory.db
	cd -
fi

if grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_BCM4343=y" ${BR2_CONFIG}; then
create_bcm4343w_firmware_archive fcc
create_bcm4343w_firmware_archive etsi
create_bcm4343w_firmware_archive jp
fi

if grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_BCM4339=y" ${BR2_CONFIG}; then
create_bcm4339_firmware_archive fcc
create_bcm4339_firmware_archive etsi
create_bcm4339_firmware_archive ic
create_bcm4339_firmware_archive jp
fi

create_bcm43439_firmware_archive

create_bcm4373_sdio_uart_firmware_archive sa sa
create_bcm4373_sdio_uart_firmware_archive div div
create_bcm4373_sdio_uart_firmware_archive sa_m2 sa-m2

create_bcm4373_usb_usb_firmware_archive sa sa
create_bcm4373_usb_usb_firmware_archive div div
create_bcm4373_usb_usb_firmware_archive sa_m2 sa-m2

create_cyw5557x_firmware_archive()
{
	grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_${1^^}_${2^^}=y" ${BR2_CONFIG} || return

	local CYPRESS_DIR=${FW_DIR}/cypress
	FW_PROD=lwb6plus

	(
	cd ${TARGET_DIR}
	tar -cjf "${BINARIES_DIR}/laird-${FW_PROD}-${2}-firmware${RELEASE_SUFFIX}.tar.bz2" \
		lib/firmware/brcm/CYW55560A1.hcd \
		lib/firmware/cypress/CYW55560A1_*.hcd \
		lib/firmware/cypress/cyfmac55572-${2}.trxse \
		lib/firmware/cypress/cyfmac55572-${2}-prod*.trxse \
		lib/firmware/cypress/cyfmac55572-${2}.txt \
		lib/firmware/cypress/cyfmac55572-${FW_PROD}.txt \
		lib/firmware/cypress/cyfmac55572-${FW_PROD}*.clm_blob \
		lib/firmware/cypress/cyfmac55572-${2}.clm_blob \
		-C ${BOARD_DIR} \
		LICENSE
	)
}

create_cyw5557x_firmware_archive cyw55573 pcie
create_cyw5557x_firmware_archive cyw55573 sdio

if grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_AR6003=y" ${BR2_CONFIG}; then
ln -rsf ${FW_DIR}/regulatory_45.db ${FW_DIR}/regulatory.db
tar -cjf "${BINARIES_DIR}/laird-ath6k-6003-firmware${RELEASE_SUFFIX}.tar.bz2" \
	-C ${TARGET_DIR} \
	--owner=0 --group=0 --numeric-owner \
	lib/firmware/ath6k/AR6003 \
	lib/firmware/regulatory_45.db \
	lib/firmware/regulatory.db
fi

if grep -qF "BR2_PACKAGE_LAIRD_FIRMWARE_AR6004=y" ${BR2_CONFIG}; then
ln -rsf ${FW_DIR}/regulatory_50.db ${FW_DIR}/regulatory.db
tar -cjf "${BINARIES_DIR}/laird-ath6k-6004-firmware${RELEASE_SUFFIX}.tar.bz2" \
	-C ${TARGET_DIR} \
	--owner=0 --group=0 --numeric-owner \
	lib/firmware/ath6k/AR6004 \
	lib/firmware/bluetopia \
	lib/firmware/regulatory_50.db \
	lib/firmware/regulatory.db
fi

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: done."
