ifeq ($(KERNELRELEASE),)

$(error KERNEL_PATH=$(KERNEL_PATH))
$(info KERNEL_SRC=$(KERNEL_SRC))

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

.DEFAULT: modules

modules modules_install clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) $@

else

obj-m += arducam-pivariety.o

endif
