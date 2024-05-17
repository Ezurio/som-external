# Introduction
## Purpose
The Sentrius™ IG60-SERIAL Summit Linux Build is a fully featured IoT gateway powered by Ezurio's 60-SOM. It has a small footprint for easy installation and a rugged, industrial spec design that enables it to withstand wide temperature ranges, humidity, shock, and vibration. Certified for industrial environments, the IG60-SERIAL is ideal for challenging deployments.

The IG60-SERIAL provides several wired and wireless interfaces for your application, or can even provide the platform for your IoT product.

The IG60-SERIAL comes standard with IEEE 802.11ac 2x2, Bluetooth 5.1, Ethernet, USB, and SD card interfaces. There are several different hardware configurations available, which support the following connectivity options:

    Serial/Modbus via RS-232/RS-422/RS-485 (IG60-SERIAL)
    Bluetooth 5 co-processor with 2 Mbps, 1 Mbps, and 1.25 kbps coded PHY operation (IG60-BL654)
    LTE Cat-1 support via supported mobile providers AT&T, Vodaphone (LTE Versions)

The IG60-SERIAL can be developed for endless applications, such as:

    Remotely monitor and control your infrastructure and surveillance equipment on pipelines, meters, pumps and valves in any energy, utility or industrial application.
    Instantly connect your equipment at remote locations or temporary sites.
    Provide reliable internet connectivity to remote workers.
    Connect your machines to an IoT platform (Such as Microsoft Azure, Amazon AWS, and PTC ThingWorx, etc.) for continuous monitoring and visualization.

The Sentrius™ IG60-SERIAL Summit Linux Build is based on Ezurio 60 Series SOM, and takes full advantage of the hardware, security, full board support package, and performance enhancements of the 60 SOM. It features a dedicated onboard FIPS 140-2 cryptographic engine for full encryption without impact to the rest of your application. It features wireless performance enhancements and bug fixes beyond what is available in open source components. And it provides fast roaming, high-bandwidth 2x2 MU-MIMO, and many configurable customizations for demanding wireless applications.

# Software Information

## Prerequisites
The Sentrius™ IG60 Summit Linux Build is based on Ezurio's 60 Series SOM module, and is similarly configured and developed. This guide is designed to walk you through Ezurio's development process for the IG60-SERIAL, including the Ezurio Linux board support package. The most seamless workflow for developing your application for the IG60-SERIAL is to set up a GitHub account, configure your SSH keys, and then install and configure Git on your development PC.

### Ubuntu
Ezurio recommends Ubuntu 22.04 64-bit as the base operating system for your development. All instructions in this reference guide assume a developer on an Ubuntu 22.04 64-bit system. If using other than Ubuntu 18.04 64-bit, please ensure you Linux distribution is a 64-bit variant as the cross-compiling toolchain requires a 64-bit Linux environment.

### SSH
Ezurio makes extensive use of GitHub and having proper Secure Shell (SSH) access to our repositories on GitHub. If you haven't set up SSH, you can use the instructions below to enable SSH for use with GitHub.
1. Check whether your private key (~/.ssh/id_rsa) and public key (~/.ssh/id_rsa.pub) files exist
  1. `$ ls -1 ~/.ssh/id_rsa*`
2. If they do not, generate them
  1. `$ ssh-keygen`
    1. Accept default file paths
    2. Accept no passphrase
3. View your public key
  1. `$ cat ~/.ssh/id_rsa.pub`

### git
Ezurio delivers the Summit Linux board support package using git repositories. If you haven't set up git, you can use the instructions below to enable git for use with GitHub.
* Install and configure the "git" package
  1. `$ sudo apt install git`
  2. `$ git config --global user.name "John Doe"`
  3. `$ git config --global user.email "john.doe@yourcompany.com"`
  4. `$ git config --list`
    1. Expect user.name=John Doe
    2. Expect user.email=john.doe@yourcompany.com

### repo
Ezurio uses the repo tool from the Android project to pull down and correctly layout the git repositories that comprise the Summit Linux board support package. To install repo on Ubuntu, use the instructions below.
* `$ sudo apt install repo`

You can also get it by following the instructions here:
* (https://source.android.com/source/downloading.html#installing-repo)

### Github Account
Summit Linux board support packages are availabe on GitHub. The most seamless workflow throughout a integration is to set up a GitHub account (https://github.com/) and add your SSH public key to your GitHub account. Instructions for setting up a GitHub account and adding an SSH key are below.
1. Go to (https://github.com/join) and follow the instructions.
2. Once you have a GitHub account add your public SSH key generated previously.
  1. View your public key
    1. `$ cat ~/.ssh/id_rsa.pub`
  2. This should be similar to:
    1. `ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW5HxCJe56MZKkGxtHU2hkb1uyuJ3i+AFZNnSIApiDe1l1H9Y40YjBF+sE47GKgNuzQIMqKZ6xjRdb8KxvtjQIE/VcSiz9KIaFtKce/wKKxy0vOXbskSLzELlA9ovY9AJmp3qUaW+BEChnggERjPvq+1oyiKGRJzo51j/CQr+Yx8c2MtKubjHknKkQ2Th8kxL1bQj4lVgyfqNGj3DXUz9S+kTm+dLnmmOXlUfxx8Khrb7j0Dg+lk1lqeolqt6aFwpMnb8V2h5lDevJ0YSSyId01OnaAnIlx1lc+zauctsgtZf5Htl9cXS7Cp3OCMfSa+IKFeFL9/ku9C25EdA5zOnt your@email.com`
  3. Copy the contents of the above output to you clipboard
  4. Follow the instructions at
	 (https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/) starting with Step 2.

## Summit Linux
### Overview
Summit Linux is board support package specifically tailored for Summit gateways and customer's connectivity driven use cases. We regularly update Summit Linux by merging in the upstream Linux kernel and Buildroot. We merge in major long-term support kernel releases which allow our gateways to utilize the latest in drivers and kernel space functionality, performance enhancements, security, and bug fixes.  Also, we merge in major long-term support Buildroot releases which provide for the latest in over 2200 user space applications and libraries. Summit Linux takes this solid upstream heritage and integrates our custom platform enhancements for connectivity, security, and power consumption.

### Buildroot
The core piece of Summit Linux is [Buildroot](https://buildroot.org/). Buildroot is a from source build system designed to allow the customer to create a customized Linux image for a target embedded computing module. Buildroot is capable of configuring and building the bootloader, kernel, and rootfs for Ezurio's gateways. Buildroot's core build system technologies are the well-known and easy to understand [make](https://en.wikipedia.org/wiki/Make_(software)) build tool and [kconfig](https://www.kernel.org/doc/Documentation/kbuild/kconfig-language.txt) configuration tool. This enables easy build customization through the user interface tools [menuconfig](https://en.wikipedia.org/wiki/Menuconfig) or xconfig and Buildroot make commands. The [Linux kernel](https://www.kernel.org/), [U-Boot bootloader](http://www.denx.de/wiki/U-Boot/WebHome), and [Busybox core userspace ulilities toolkit](https://en.wikipedia.org/wiki/BusyBox) all use make, Kconfig, and menuconfig. Build and configuration concepts found in one translate nicely to another. Buildroot has easy to read and extensive documentation available at (https://buildroot.org/docs.html) in pdf, html, and ascii form.  If time permits, Ezurio highly recommends following the Training section of the documentation landing page.

Summit Buildroot is a fork of the upstream [Buildroot stable](https://git.busybox.net/buildroot/). Starting with and merging upstream allows Ezurio to know the authenticity of Buildroot's source code and better verify the security of our fork. Ezurio targets [long-term support releases (LTS)](https://buildroot.org/download.html) for merging into our Buildroot fork.

### Linux Kernel
Summit kernel is a fork the upstream [Linux stable kernel](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/). Starting with and merging upstream allows Ezurio to know the authenticity of the kernel's source code and better verify the security of our fork. We target [long-term support releases (LTS)](https://www.kernel.org/category/releases.html) for merging into our kernel fork.

### Toolchain
Prebuilt toolchains preselected for each release of Summit Linux for our gateways. The advantage of using a preselected and prebuilt toolchain is the high level of QA verification on common components between stock Summit development images and customer images. Each Summit Linux release is configured to automatically download and use the correct toolchain.

## Getting Started with Summit Linux
This section will walk a developer through following:

* [Downloading a developer's SD card image](#downloading-a-developers-sd-card-image)
* [Flashing a developer's SD card image](#flashing-a-developers-sd-card-image)
* [Using a prebuilt SDK](#using-a-prebuilt-sdk)
* [Manifest file](#Manifest-file)
* [Downloading the board support package source code](#downloading-the-board-support-package-source-code)
* [Building the developer's SD card image](#building-the-sd-card-developers-image)
* [Building the NAND image](#building-the-NAND-image)
* [Software update](#Software-update)
* [Setup web server](#Setup-web-server)
* [Buildroot cache](#Buildroot-cache)
* [Creating a custom SDK](#create-a-custom-sdk)

### Downloading a developer's SD card image
Summit Linux releases include a prebuilt SD card image as a starting point for evaluating and integrating a Summit Linux release on a Summit gateway. For the IG60, these prebuilt images are found on at [IG60 Summit Linux release page](https://github.com/EzurioCP/IG60-Ezurio-Linux-Release-Packages/releases). These releases are named ig60llsd-summit-A.B.C.D.tar.bz2. These prebuilt SD card images are good for quickly testing a IG running the latest software.

### Flashing a developer's SD card image
Once the image is downloaded. Extract the image:
```
~/Downloads/ig60llsd$ tar -xvf ig60llsd-summit-12.x.y.z.tar.bz2
ig60llsd-summit-12.x.y.z/
ig60llsd-summit-12.x.y.z/target-sbom
ig60llsd-summit-12.x.y.z/host-sbom
ig60llsd-summit-12.x.y.z/u-boot-spl.bin
ig60llsd-summit-12.x.y.z/u-boot.itb
ig60llsd-summit-12.x.y.z/rootfs.tar
ig60llsd-summit-12.x.y.z/ig60llsd-sdk.tar.bz2
ig60llsd-summit-12.x.y.z/legal-info.tar.bz2
ig60llsd-summit-12.x.y.z/kernel.itb
ig60llsd-summit-12.x.y.z/mksdcard.sh
ig60llsd-summit-12.x.y.z/mksdimg.sh

```
To flash the image to an SD card use the mksdcard.sh script. The mksdcard.sh script takes the target device as an argument and will ask if you'd like to proceed with removing all data on your SD card and flashing a new image.  This is shown below:
```
~/Downloads/ig60llsd-summit-12.x.y.z$ sudo ./mksdcard.sh /dev/sdc
[sudo] password for user:
*************************************************************************
WARNING: All data on /dev/sdc now will be destroyed! Continue? [y/n]
*************************************************************************
[Partitioning /dev/sdc...]
1024+0 records in
1024+0 records out
1048576 bytes (1.0 MB, 1.0 MiB) copied, 0.653846 s, 1.6 MB/s
DISK SIZE - 1967128576 bytes
Checking that no-one is using this disk right now ... OK

Disk /dev/sdc: 1.9 GiB, 1967128576 bytes, 3842048 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes

>>> Created a new DOS disklabel with disk identifier 0x59c337f4.
Created a new partition 1 of type 'W95 FAT16 (LBA)' and of size 48 MiB.
/dev/sdc2: Created a new partition 2 of type 'Linux' and of size 1.8 GiB.
/dev/sdc3:
New situation:

Device     Boot  Start     End Sectors  Size Id Type
/dev/sdc1  *      2048  100351   98304   48M  e W95 FAT16 (LBA)
/dev/sdc2       100352 3842047 3741696  1.8G 83 Linux

The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
[Making filesystems...]
[Copying files...]
[Done]
```
You can now insert your SD card into the IG hardware development kit and press the reset button to boot into the new SD card image.

### Flashing a developer's SD card image on Windows 7 or later

If you are not able to access USB flash drives on a virtual machine, here is a way to flash the image on windows. You have to download and install [balenaEtcher](https://www.balena.io/etcher/) first.
```
1. Build an image on ubuntu after download and extract ig60llsd-summit-12.x.y.z.tar.bz2:
   ~/Downloads/ig60llsd-summit-12.x.y.z$ sudo ./mksdimg.sh sdimage
   and copy sdimage.xz to Windows.

3. Go to Windows Start menu and click `balenaEtcher`, then select sdimage.xz as source file and sd card as the target.

4. Click `Flash` and wait until it finishes.
```

### Using a prebuilt SDK

Summit Linux releases include a prebuilt SDK to start doing application development for a Ezurio IG. For the IG60, this prebuilt SDK is called ig60llsd-sdk-A.B.C.D.tar.bz2 and can be found with each release at the [IG60 Summit Linux release page](https://github.com/EzurioCP/IG60-Ezurio-Linux-Release-Packages/releases). The prebuilt SDK includes the toolchain and all development files of the software packages used to generate the prebuilt SD card image from that release. The SDK can be set up for use with an IDE to allow application developers to not need a full BSP on their system. To use the SDK, extract the SDK tarball then run the script relocate-sdk.sh (located at the top directory of the SDK), to make sure all paths are updated with the new location. For more information on using SDKs generated from Ezurio's Buildroot fork, see the [Buildroot manual's section on the SDK](https://buildroot.org/downloads/manual/manual.html#_advanced_usage).

### Manifest file

Ezurio provides manifest files for customers to obtain released resources. Each manifest file describes the projects that are available and how to fetch them. A typical manifest file has `remote`, `default` and `project` elements. The `remote` element specifies the git url and revision shared by one or more projects. The `default` element specifies the the default `remote` element to be used by projects. The `project` element specifies the repository to be cloned. Its `name` attribute will be appended to the `remote` git url to generate the actual address. The `path` attribute defines the relative path to the top working directory to place the project. Following is an example of the manifest file:
```
<?xml version="1.0" encoding="UTF-8">
<manifest>
    <remote name="origin" fetch="ssh://git@github.com/EzurioCP" />
    <default remote="origin" revision="refs/tags/LRD-REL-12.x.y.z" />
    <project path="som-external" name="som-external.git" />
 </manifest>
```
A `remote` element is defined here, which is also the default. Project `som-external.git` will be fetched from `https://github.com/EzurioCP/som-external.git` with revision `refs/tags/LRD-REL-12.x.y.z`.

### Downloading the board support package source code

First step, pick which release you want. Odds are you want the most recent of your release.

Next, use repo to initalize and fetch your release. This is a two-step process: first you tell repo which manifest to use and then you tell it to fetch everything.

    mkdir lrd-12.x.y.z
    cd lrd-12.x.y.z
    repo init -u git@github.com:EzurioCP/IG60-Ezurio-Linux-Release-Packages.git -m ig60_12.x.y.z.xml
    repo sync

_Note: Repo will initialize a .repo directory and then place all files directly in the directory that you are in when you run the `repo` command. So we recommend making a subdirectory and working in there._

### Building the SD Card developer's image
Once your repo sync is finished, you are ready to build your own SD card image. This can be achieved by the following:

    make -C som-external/ ig60llsd

Once your build completes, you will find the output similar to below:
```
~/git/lrd-12.x.y.z$ cd buildroot/output/ig60llsd/images/
~/git/lrd-12.x.y.z/buildroot/output/ig60llsd/images$ ls -al
at91-ig60ll.dtb
boot.scr -> ../../../board/configs-common/image/boot_mmc.scr
ig60sd-summit.tar.bz2
Image
Image.gz
kernel.itb
kernel.its
mksdcard.sh -> ../../../board/scripts-common/mksdcard.sh
mksdimg.sh -> ../../../board/scripts-common/mksdimg.sh
rootfs.tar
u-boot.dtb
u-boot.itb
u-boot.its -> ../../../board/configs-common/image/u-boot.its
u-boot-nodtb.bin
u-boot.scr -> ../../../board/configs-common/image/u-boot_mmc.scr
u-boot.scr.itb
u-boot.scr.its -> ../../../board/configs-common/image/u-boot.scr.its
u-boot-spl.bin
u-boot-spl.dtb
u-boot-spl-nodtb.bin

```
Go to images/ and run `sudo ./mksdcard.sh /dev/sd-device` to flash the SD card.

### Building the NAND image
NAND image can be built by the following:

    make -C som-external/ ig60ll

Once your build completes, you will find the output similar to below:
```
~/git/lrd-12.x.y.z$ cd buildroot/output/ig60ll/images/
~/git/lrd-12.x.y.z/buildroot/output/ig60ll/images$ ls -al
at91-ig60ll.dtb
boot.bin
boot.scr -> ../../../board/configs-common/image/boot.scr
erase_data.sh -> ../../../board/scripts-common/erase_data.sh
ig60ll-summit.tar.bz2
ig60ll.swu
Image
Image.gz
kernel.itb
kernel.its
rootfs.bin -> rootfs.squashfs
rootfs.squashfs
sw-description
u-boot.dtb
u-boot-env.tgz -> ../../../board/configs-common/image/u-boot-env.tgz
u-boot.itb
u-boot.its -> ../../../board/configs-common/image/u-boot.its
u-boot-nodtb.bin
u-boot.scr -> ../../../board/configs-common/image/u-boot.scr
u-boot.scr.itb
u-boot.scr.its -> ../../../board/configs-common/image/u-boot.scr.its
u-boot-spl.bin
u-boot-spl.dtb
u-boot-spl-nodtb.bin

```
`ig60ll.swu` is the image for software update.

### Software update
IG60 adopts the concept of double copy(A/B system) to improve safety and reliability. Each copy contains both the kernel and rootfs images. The u-boot environment variable 'bootside' determines the working copy.

Software update is performed efficiently with SWUpdate. All images and scripts are appended to a single .swu file by the Buildroot. In addition, it must have a description file to specify software collections and operation modes to implement the double copy strategy. By default the software description file has five collections: `main-a`, `main-b`, `full-a`, `full-b` and `complete`. `main-a(b)` is to update kernel and rootfs images of copy `a(b)`. `full-a(b)` will also update bootstrap and u-boot images. `complete` is for ig60llsd only. It will re-partition and then program the entire NAND, thus to initialize an IG60 device.

IG60 supports 3 ways to update software: `local update`, `auto update` and `download update`. Update is performed according to the selected collection. However, it is not allowed to update the kernel and rootfs of the working copy. We have to run `fw_printenv bootside` to get the correct standby copy information for local update and download update. The u-boot environment variable 'bootside' will be automatically updated when it is completed. Reboot is required to run the new image.
1. Local update
   Insert a USB disk with .swu file(USB disk must be formatted to fat32 or ext4), which will be automatically mounted to `/media/`. Perform software update by setting the collection, i.g 'main-a', 'full-b':

       fw_update </path/to/swu/file>

2. Auto update(secure update service needs to be enabled)
   Insert a USB disk with .swu file(USB disk must be formatted to fat32 or ext4). The secure update service checks whether file `/media/sda1/swupdate.swu` exists, and then starts an update;

3. Download update
    Software can be updated remotely if a http server is available. Make sure .swu file is already in the web directory before update begins.

        fw_update <url of .swu file>

### Setup web server
Python's simple built-in web server here. Go to the dir where images are saved, and run following command to start the web service
```
python -m SimpleHTTPServer 8000
```
For python3, the command is
```
python3 -m http.server 8000
```

### Buildroot cache
In order to speed up builds, set up a Buildroot cache to store sources that Buildroot will download. Off your home directory:

    mkdir ~/.br2_dl_dir

Then add it to your build environment:

    export BR2_DL_DIR="${HOME}/.br2_dl_dir"


### Create a custom SDK
If you'd like to create a custom SDK from your customized source build, while in the target's output directory, issue a `make sdk`:
```
~/git/lrd-12.x.y.z/buildroot/output/ig60llsd$ make sdk
```

## NetworkManager
We are using our own customized fork of NetworkManager for networking configuration, including WiFi profile management. For more information on using NetworkManager please see our [Summit NetworkManager User Guide](https://github.com/EzurioCP/SOM60-Release-Packages/releases/download/LRD-REL-6.0.0.138/user_guide_laird_networkmanager_0.1.pdf).

## Summit Buildroot br2-external
The br2-external mechanism provides a convenient way to customize project specific configure files, packages etc. outside of the Buildroot source tree. Following is an example layout of Summit Buildroot br2-external tree:
```
|--Config.in
|--external.desc
|--external.mk
|--Makefile
|--configs/
|    |--buildroot_defconfig
|--board/
|    |--rootfs-additions/
|    |--kernel_defconfig
|    |--u-boot_defconfig
|    |--u-boot.scr
|    |--post_build.sh
|    |--post_image.sh
|    |--kernel-dts/
|    |    |--kernel.dts
|    |--uboot-dts/
|    |    |--uboot.dts
|--package/
|    |--package-1/
|    |    |--Config.in
|    |    |--package-1.mk
|    |    |--src/
|    |--package-2/
|         |--Config.in
|         |--package-2.mk
|         |--package-2.hash
|--README
```
`external.desc`: provides the `name` and an optional short description for the br2-external tree:
```
name: DEMO
desc: Custom Project Demo
```
 The full path of the br2-external tree will be set to `BR2_EXTERNAL_$(NAME)_PATH` automatically so that it can be used in both Buildroot Kconfig and Makefile. In this case `BR2_EXTERNAL_DEMO_PATH` is set to the full path of `demo` project.

`Config.in`: define custom package recipes with `external.mk` so they are visible to the top-level Buildroot configuration menu:
```
source "$BR2_EXTERNAL_DEMO_PATH/package/package-1/Config.in"
source "$BR2_EXTERNAL_DEMO_PATH/package/package-2/Config.in"
```
`external.mk`: define custom package recipes with `Config.in` so they can be built by the Buildroot make logic.
```
include $(sort $(wildcard $(BR2_EXTERNAL_DEMO_PATH)/package/*/*.mk))
```

`Makefile`: defines the build targets
```
TARGETS = demo

MK_DIR = $(realpath $(dir $(firstword $(MAKEFILE_LIST))))
BR_DIR = $(realpath $(MK_DIR)/../buildroot)

include $(BR_DIR)/board/build-rules.mk
```
Run `make -C <custom-project-dir> demo` to invoke the build.

`configs`: where Buildroot configure files for the custom project are saved. Run `make menuconfig` to configure kernel, u-boot, packages etc. Run `make savedefconfig` to save it.

`board`: where custom board support files and configures are saved, including kernel and u-boot configures, scripts, files need installed to the target rootfs, etc.

Board support files and configures

Board support files and configures are used to customize kernel, uboot, target rootfs and even the images.

To customize kernel with kernel_defconfig, go to `Buildroot-->Kernel-->Configuration file path` and set it to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/kernel_defconfig`.

To customize uboot with uboot_defconfig, go to `Buildroot-->Bootloaders-->Configuration file path` and set it to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/u-boot_defconfig`.

To customize kernel device tree with kernel.dts, go to `Buildroot-->Kernel`, enable `Build a Device Tree Blob (DTB)` and set `Out-of-tree Device Tree Source file paths` to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/kernel-dts/kernel.dts`. If there are more than one dts files, a list of dts paths separated by space needs to be provided.

To customize uboot device tree with uboot.dts, go to `Buildroot-->Bootloaders-->Device Tree Source file paths` and set it to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/uboot-dts/uboot.dts`. If there are more than one dts files, a list of dts paths separated by space needs to be provided.

To customize target rootfs, go to
`Buildroot-->System configuration-->Custom scripts to run before creating filesystem images` and set it to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/post_build.sh`. A typical usage of post_build.sh is to install custom materials to the target rootfs:
```
1 rsync -rlptDWK --exclude=.empty "${BR2_EXTERNAL_DEMO_PATH}/board/rootfs-additions/" "${TARGET_DIR}"
2
3 ${BASE_DIR}/../../board/som60/post_build.sh ${1} ${2}
```
Line 3 is to invoke the post-build script in the Buildroot source tree.

To customize images, go to `Buildroot-->System configuration-->Custom scripts to run after creating filesystem images` and set it to `($(BR2_EXTERNAL_$(DEMO)_PATH)/board/post_image.sh`. However, this is not encouraged as it may result in corrupted images and boot faiulre.

To customize u-boot environment, the u-boot script file `u-boot.scr` in the Buildroot source tree needs to be overridden. This can be done by appending a line to the post_build.sh:
```
ln -rsf ${BR2_EXTERNAL_DEMO_PATH}/board/u-boot.scr ${BINARIES_DIR}/u-boot.scr
```
The custom `u-boot.scr` must contain following information to boot the device. New environment varaibles should be added to the begin of the script.
```
if test ${bootside} = a;
then
    setenv bootvol 1
else
    setenv bootvol 4
fi

ubi part ubi
ubi read 0x21000000 kernel_${bootside}
source 0x21000000:script
bootm 0x21000000
```

Add a custom package

Here is the instruction to add a custom package `test`, assuming its source code is saved in `package/test/src`:
1. Go to the `demo` project and run `mkdir -p package/test/`;
2. Go to `package/test/` and create Config.in, which basically contains:
```
    config BR2_PACKAGE_TEST
        bool "test"
        depends on BR2_PACKAGE_LIBA
        select BR2_PACKAGE_LIBB
        help
            This is an example to add a package to the br2-external tree.
```
3. Create test.mk, which describes how to copy/download, configure, build and install the package:
```
    TEST_VERSION = 1.0.0
    TEST_SITE = $(BR2_EXTERNAL_DEMO_PATH)/package/test/src
    TEST_SITE_METHOD = local
    TEST_LICENSE = GPL-3.0+
    TEST_LICENSE_FILES = COPYING
    TEST_DEPENDENCIES = liba libb

    define TEST_BUILD_CMDS
        $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
    endef

    define TEST_INSTALL_TARGET_CMDS
        $(INSTALL) -D -m 0755 $(@D)/test $(TARGET_DIR)/usr/sbin/
    endef

    $(eval $(generic-package))
```
4. Append following line to demo/Config.in

    source "$BR2_EXTERNAL_DEMO_PATH/package/test/Config.in"

Now the package can be configured and built within the Buildroot.
More information is available at (https://buildroot.org/downloads/manual/manual.html#adding-packages).

Add a package from manifest

To add a custom package from github etc, a `project` elemenent needs to be added to the manifest file .repo/manifests/custom.xml:

    <project path="demo/package/externals/test" name="test.git">

where `externals/test` is the place to save the source code of the package. If the project is in a repository other than the default, a `remote` element also needs to be added

    <remote name="custom" fetch="ssh://git@github.com/custom" />
    <project remote="custom" path="demo/package/externals/test" name="test.git" revision="custom-12.x.y.z">

Run `repo sync` to fetch the source code, and then follow the instruction of `Add a custom package` to make it configurable and buildable.

## File System
This section describes the filesystem and booting strategies for all products based on the 60 Series SOM. These products introduce a new set of features that changes the way the embedded Linux filesystems are built and programmed onto the embedded NAND flash.

### What's Changed?
The following is a brief description of the changes from Ezuro's previous system on module (the WB50NBT) to the 60 Series SOM (and subsequently the IG60-SERIAL):
```
    AT91Bootstrap has been replaced with U-Boot SPL
    U-Boot is now programmed as a FIT (flattened device tree) image
    The kernel is now programmed as FIT image
    The kernel, rootfs, and overlay filesystems are now stored as UBI volumes inside of a single UBI disk
    (Optional) FIT image signing is enabled to verify both U-Boot and the kernel
    (Optional) DM-Verity is enabled to verify the data stored on the rootfs is authentic
```

### Detailed Description
The following is a detail description of the new components & strategies.

#### U-Boot SPL
AT91Bootstrap has been replaced as the first-level bootloader, by U-Boot SPL. This is pretty much a transparent change for developers; the new bootloader resides in the same location in NAND flash (0x00000000 - 0x00020000). The change was made to enable the use of FIT image signing, so that U-Boot SPL can verify U-Boot.

#### U-Boot FIT Image
U-Boot (the second-stage bootloader) is now built as a FIT (flattened image tree) image. (For this reason, the name of the artifact is now u-boot.itb, which denotes a binary FIT image). This enables U-Boot to contain its own device tree, which can also be used to contain keys that are used to verify the kernel image.

#### Kernel FIT Image
The kernel is now built as a FIT (flattened image tree) image. (For this reason, the name of the artifact is now kernel.itb, which denotes a binary FIT image). The kernel's device tree is now contained within the FIT image, so that it can be signed inside of a configuration (verified using the key stored in U-Boot). The kernel FIT image may also contain a script file that is used to mount the rootfs. This is done so that the script can (optionally) verify the root hash of the rootfs (known as the "verity" hash, provided by the verity module). For this reason, when verity is enabled, the kernel FIT image and the rootfs are paired and must always be flashed together.

#### UBI Disk Layout
The kernel, rootfs, and overlay file systems are now stored as UBI ''volumes'' contained within a single (large) UBI disk. This change improves wear-leveling and fault tolerance, since the volumes are stored in blocks across the entire disk. This changes the way the kernel and rootfs are flashed on the device. Both U-Boot and the kernel are informed (via their device trees) of the single UBI disk. The volume information (size, etc.) is contained within the UBI disk itself (not stored in the device configuration). For convenience, U-Boot has a script, `_ubiformat`, which performs formatting of the UBI disk and creation of all the named volumes required for an A/B kernel and rootfs.

### Tips & Tricks
####Custom UBI Volume Sizes
Since the UBI volumes are dynamic (stored in the UBI disk), you can easily change the formatting (for example, if you don't need a "B" configuration during development, then you can reclaim that space for development use in the "A" side.) Just use the `_ubiformat` script as a template to format the UBI disk and create the partitions.

## Enabling LTE (select models)
Note: This section is relevant to the following parts with LTE:
```
    IG60-SERIAL-LTE
    IG60-BL654-LTE
```
To enable LTE in the IG60-SERIAL, you'll need to manually set the correct pin. Until you enable this, LTE is non-functional. The pin is mapped to sysfs. To enable LTE, use the following command:
```
# echo 0 > /sys/devices/platform/gpio/lte_on/value
```
### Using the Modem DBus API
The Sentrius IG60 provides access to the embedded LTE modem using the [Linux oFono service](https://git.kernel.org/pub/scm/network/ofono/ofono.git) and associated APIs. You can find an example of the [Modem DBus AP](https://github.com/EzurioCP/igsdk/blob/master/python/igsdk/modem.py) here.
