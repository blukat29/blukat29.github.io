---
layout: post
title: Building custom kernel
category: dev
---

Use VM when you practice, just in case.

### 1. Download kernel

Download from <https://www.kernel.org/pub/linux/kernel/>.
For example,

```
sudo apt-get install -y wget xz-utils
wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.9.28.tar.xz
tar xf linux-4.9.28.tar.xz
```

### 2. Make your modification

Patch the files, add code, ... etc.

### 3. Config

Copy current setting.

```
sudo cat /boot/config-`uname -r` > .config
make olddefconfig
```

### 4. Build

```
make -j4
make -j4 modules
```

### 5. Install

```
sudo make modules_install
sudo make install
```

Files will be written to `/boot` directory.

### 6. Reboot

Reboot the computer. If anything goes wrong, reboot again and select original kernel.

### (Optional) Change default boot kernel

[See here](https://askubuntu.com/a/216420)

