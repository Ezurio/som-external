ifeq ($(KERNELRELEASE),)

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

.DEFAULT: modules

modules modules_install clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) $@

else

snd-soc-tac5x1x-objs := tac5x1x.o tac5x1x-i2c.o
obj-m += snd-soc-tac5x1x.o

endif
