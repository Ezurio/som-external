
ifeq ($(KERNELRELEASE),)

KERNEL_PATH ?= /lib/modules/$(shell uname -r)/build

.PHONY: modules modules_install clean

modules:
	$(MAKE) -C $(KERNEL_PATH) M=$(CURDIR) modules

modules_install:
	$(MAKE) -C $(KERNEL_PATH) M=$(CURDIR) modules_install

clean:
	$(MAKE) -C $(KERNEL_PATH) M=$(CURDIR) clean

else

obj-m += pac193x.o

endif
