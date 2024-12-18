# https://git.ti.com/cgit/lpaa-android-drivers/tac5x1x-linux-driver/snapshot
TAC5X1X_SITE = $(TAC5X1X_PKGDIR)/files
TAC5X1X_SITE_METHOD = local

TAC5X1X_LICENSE = GPL-2.0

$(eval $(kernel-module))
$(eval $(generic-package))
