---
category: dev
layout: post
title: Cross compiling Linux ARM kernel modules
---

This guide will allow you to cross-compile a loadable kernel module (LKM; a.k.a. device driver) for a ARM Linux system.

### 1. Target system

I will use this configuration as an example, but you can apply the same method for other environments.

- ARMv7 (32-bit)
- ARM qemu emulating `vexpress-a9` board
- Linux is running in qemu.

### 2. Download linux kernel source

Download the kernel source from <https://www.kernel.org/pub/linux/kernel/>.

You must download the exact version which is running in the qemu.

Note that source for `3.2.0` is named `linux-3.2.tar.gz`, not `linux-3.2.0.tar.gz`.

### 3. Download cross compiler toolchain

Linaro's prebuilt toolchain generally works well. Download one from <https://releases.linaro.org/components/toolchain/binaries>.

Pick a version, and choose the appropriate architecture. In our case, it would be `arm-linux-gnueabihf` (ARM 32-bit, linux, little endian, hard float).

There are three kinds of files: `gcc-linaro-`, `runtime-gcc-linaro-`, and `sysroot-eglibc-linaro-`. You only need the first one. For more info, refer to this [Linaro wiki page](https://wiki.linaro.org/WorkingGroups/ToolChain/FAQ#The_prebuilt_binary_release_for_2014.11_and_onwards_look_vastly_different_from_previous_releases._What.27s_changed.3F).

For instance, go to `4.9-2017.01/arm-linux-gnueabihf/` directory and download `gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf.tar.xz`.

### 4. Take out kernel build config

We need to build the kernel first, and then build a kernel module. But to compile a kernel, we must have the exact build configuration of the currently running Linux system. Fortunately, you can get a copy from a running system. Look at these locations:

- `/proc/config.gz`
- `/boot/config`
- `/boot/config-*`

Copy the file out of the qemu using scp or something.

### 5. Build the kernel

You need auto-generated files in order to build a kernel module. Otherwise you may encounter an error message like this:

```
/home/ubuntu/linux-3.2/include/linux/kconfig.h:4:32: fatal error: generated/autoconf.h: No such file or directory
    #include <generated/autoconf.h>
                                   ^
```

To build a kernel with given config file,

```sh
cd <LINUX_SOURCE_DIR>
cp <CONFIG_FILE> .config
make ARCH=arm CROSS_COMPILE=<TOOLCHAIN_DIR>/bin/arm-linux-gnueabihf- oldconfig
make ARCH=arm CROSS_COMPILE=<TOOLCHAIN_DIR>/bin/arm-linux-gnueabihf-
```

Complete kernel build may not be necessary because what you need is generated header files.

### 6. Build the module

Write a Makefile as follows:

```make
PWD := $(shell pwd)
obj-m += hello.o

all:
        make ARCH=arm CROSS_COMPILE=$(CROSS) -C $(KERNEL) SUBDIRS=$(PWD) modules
clean:
        make -C $(KERNEL) SUBDIRS=$(PWD) clean
```

And create a hello world module.

```c
// hello.c
#include <linux/module.h>
#include <linux/kernel.h>

int init_module(void) {
    printk(KERN_INFO "Hello world.\n");
    return 0;
}

void cleanup_module(void) {
    printk(KERN_INFO "Goodbye world.\n");
}
```

Finally run this command.

```
make KERNEL=<LINUX_SOURCE_DIR> CROSS=<TOOLCHAIN_DIR>/bin/arm-linux-gnueabihf-
```

Then you will get `hello.ko` compatible with the running ARM Linux.

