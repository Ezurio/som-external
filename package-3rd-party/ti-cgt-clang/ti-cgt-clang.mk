################################################################################
#
# ti-cgt-clang
#
################################################################################

TI_CGT_CLANG_VERSION = 4.0.1.LTS
TI_CGT_CLANG_NAME = ti-cgt-armllvm_$(TI_CGT_CLANG_VERSION)
TI_CGT_CLANG_SOURCE = $(subst -,_,$(TI_CGT_CLANG_NAME))_linux-x64_installer.bin
TI_CGT_CLANG_SITE = https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-ayxs93eZNN/$(TI_CGT_CLANG_VERSION)
TI_CGT_CLANG_LICENSE = TI Text File with portions under Apache 2.0 License with LLVM exceptions
TI_CGT_CLANG_LICENSE_FILES = TI_Arm_Clang_Compiler_4.0.1_manifest.html

define HOST_TI_CGT_CLANG_EXTRACT_CMDS
	cp $(HOST_TI_CGT_CLANG_DL_DIR)/$(TI_CGT_CLANG_SOURCE) $(@D)/
	chmod +x $(@D)/$(TI_CGT_CLANG_SOURCE)
	$(@D)/$(TI_CGT_CLANG_SOURCE) --prefix $(@D) --mode unattended
endef

# Since this is largely prebuilt toolchain and likes to live in its
# own directory, put it in $(HOST_DIR)/opt/ti-cgt-clang.
# Packages wanting to use this toolchain need to use this path as TI's
# standard CGT toolchain path e.g. make CGT_TI_ARM_CLANG_PATH=$(TI_CGT_CLANG_INSTALLDIR)...
TI_CGT_CLANG_INSTALL_PREFIX = $(HOST_DIR)/opt
TI_CGT_CLANG_INSTALLDIR = $(TI_CGT_CLANG_INSTALL_PREFIX)/$(TI_CGT_CLANG_NAME)

define HOST_TI_CGT_CLANG_INSTALL_CMDS
	rm -rf $(TI_CGT_CLANG_INSTALLDIR)
	mkdir -p $(TI_CGT_CLANG_INSTALL_PREFIX)
	cp -af $(@D)/$(TI_CGT_CLANG_NAME) $(TI_CGT_CLANG_INSTALL_PREFIX)/
endef

$(eval $(host-generic-package))
