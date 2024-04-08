# enable tracing and exit on errors
set -x -e

# Path to common image files
CCONF_DIR="$(realpath ${BR2_EXTERNAL_LRD_SOM_PATH}/board/configs-common/image)"
CSCRIPT_DIR="$(realpath ${BR2_EXTERNAL_LRD_SOM_PATH}/board/scripts-common)"

# Copy the u-boot.its
ln -rsf ${CCONF_DIR}/u-boot.its ${BINARIES_DIR}/u-boot.its

# Use standard boot script
ln -rsf ${CCONF_DIR}/boot.scr ${BINARIES_DIR}/boot.scr

ln -rsf ${CCONF_DIR}/boot_mmc.scr ${BINARIES_DIR}/boot.scr
ln -rsf ${CCONF_DIR}/u-boot_mmc.scr ${BINARIES_DIR}/u-boot.scr

# Copy mksdcard.sh and mksdimg.sh to images
ln -rsf ${CSCRIPT_DIR}/mksdcard_legacy-wbx3.sh ${BINARIES_DIR}/mksdcard.sh
ln -rsf ${CSCRIPT_DIR}/mksdimg_legacy-wbx3.sh ${BINARIES_DIR}/mksdimg.sh

ln -rsf ${CCONF_DIR}/u-boot.scr.its ${BINARIES_DIR}/u-boot.scr.its
