
ifeq ($(KERNELRELEASE),)

KERNEL_PATH ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

.DEFAULT: modules

modules modules_install clean:
	$(MAKE) -C $(KERNEL_PATH) M=$(CURDIR) $@

else

obj-m += pac193x.o

endif
