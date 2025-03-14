
ifeq ($(KERNELRELEASE),)

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

.DEFAULT: modules

modules modules_install clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) $@

else

obj-m += pac193x.o

endif
