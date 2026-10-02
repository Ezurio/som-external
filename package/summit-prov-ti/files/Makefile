ifeq ($(KERNELRELEASE),)

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

modules modules_install clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) $@

else

obj-m += summit_prov.o

endif
