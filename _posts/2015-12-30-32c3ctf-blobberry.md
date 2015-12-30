---
layout: post
title: 32C3 CTF - blobberry
category: writeup
---

> We made this new Raspberry Pi OS, [check it out!](https://32c3ctf.ccc.ac/uploads/blobberry.zip)

## 1. Inspect image

The problem contains an image file (`blobberry.img`) and a link to install instruction. The [instruction](http://www.instructables.com/id/How-to-install-Rasbian-Wheezy-on-the-Raspberry-P/?ALLSTEPS) is about installing an OS on real Raspberry Pi device, which we don't have. So we decided to run it on qemu. We followed [this instruction](https://www.raspberrypi.org/forums/viewtopic.php?f=29&t=37386).

```
$ file blobberry.img
blobberry.img: x86 boot sector
$ fdisk -l blobberry.img

Disk blobberry.img: 68 MB, 68157440 bytes
87 heads, 4 sectors/track, 382 cylinders, total 133120 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x2fa1ab6c

        Device Boot      Start         End      Blocks   Id  System
blobberry.img1   *        8192      139263       65536    c  W95 FAT32 (LBA)
$ sudo mount blobberry.img -o offset=4194304 /mnt
$ ls /mnt
bootcode.bin UART.TXT
$ file /mnt/bootcode.bin
bootcode.bin: data
```

Everything went well until we saw that the image contains only two files. The image supposed to contain `/etc/ld.so.preload` file, but it didn't. `UART.TXT` is just a funny text file explaining where is UART port. And `bootcode.bin` seemed to be our task. After some googling, we've found that `bootcode.bin` is "secondary boot loader" that runs on Raspberry Pi's GPU.

## 2. Reverse bootcode.bin

Raspberry Pi's GPU is "Broadcom VideoCore IV processor". We used an in-browser disassembler for this architecture (<http://hermanhermitage.github.io/videocore-disjs/>). Then we reverse engineered the assembly. These resources helped me a lot with understanding the architecture:

- https://github.com/hermanhermitage/videocoreiv/wiki/VideoCore-IV-Programmers-Manual
- https://github.com/hermanhermitage/videocoreiv/wiki/Register-Documentation
- http://www.broadcom.com/docs/support/videocore/VideoCoreIV-AG100-R.pdf

The program receives an input, checks it, and prints out either "correct" or "wrong". The input checking routine looks like this:

```c
char buf[0x28]; // from 0x31b. This contains the input
char m[256]; // from 0x0. This area is initialized to 0.
char A[16]; // from 0x204. This area contains some data.
char B[256]; // from 0x7d6. This area contains some data.

void putchar(int r0); // 0x702
void sleep(int r0); // 0x5c6

int sub_792() // returns 0 if corrrect.
{
  r6 = 0;
  while (1) {
    if (r6 & 4 == 0) GPIO_CLR0 = 0x10000;
    else GPIO_SET0 = 0x10000;
    putchar(8); // '\r'
    r0 = 0x7d2 + (r6 & 3); // 0x7d2: "/-\|"
    putchar(r0);
    sleep(100);
    sub_87c(r6);
    r6 ++;
  }
loc_7ce:
  return r10;
}

void sub_87c(int r6)
{
  if (r6 == 0)
  {
    r10 = 0;
    for (i=0; i<0x100; i++)
      m[i] = i;
    return;
  }
  if (r6 == 1)
  {
    j = 0;
    for (i = 0; i < 0x100; i ++)
    {
      prev = m[i];
      j = (j + m[i] + A[i%16]) & 0xff;
      m[i] = m[j];
      m[j] = prev;
    }
    j = 0;
    return;
  }
  if (r6 > 1)
  {
    i = (r6 - 1) & 0xff;

    k = m[i];
    j = (j + m[i]) & 0xff;
    m[i] = m[j];
    m[j] = k;

    k = (k + m[j]) & 0xff;
    k = m[k];

    x = buf[i-1];
    y = B[i];
    r10 |= (x ^ y ^ k);

    if (x == 0) goto loc_7ce;
    else return
  }
}
```

Keygen was quite straightforward.

```py
m = [0]*256 # 0x0
A = map(ord, "01e80400207e1008e0e8ffffe3ffa0e9".decode('hex')) # 0x204
B = """
0012 9d4b 6359 37ea 1e68
8749 db74 a293 57f2 4405 4585 c38d 4460
e12c f3f9 17b7 2e9e 492b 4749 1f4c e599
a7f7 d370 4051 50ce 58e8 7b02 ef3b b1db
47aa 26fa 233f bc6f 4765 e245 477c 7555
36e8 e586 cd73 49f2 2938 cea6 e86f 1849
9d05 0ff1 b5eb 3db6 625f 4bf0 dfc8 026f
efc6 cc43 b29d e438 9ceb 3a87 12bc ec39
4846 17a3 68c6 45dc 6ca3 d570 8fc4 05d2
662a 60aa 8c0e 5810 9c13 9ed4 cd71 e7c8
6e81 b890 9afe 05d2 9a03 9700 066a 2918
166a 3118 166a 009d 4900 6940 1966 e9b0
ff00 0760 9742 7d0c dc42 ecb0 ff00 0e60
ce42 ef0c 7f0d ed0d fd42 edb0 ff00 0d62
dd0c 00b0 1a03 9042 000c 01b0 d607 9142
110c 0145 1d45 da4d 006a 7f90 82ff 5a00
0a60 0960 0760 9742 790d 1962 49b1 0001
fa18 5a00 0c60 0960 0760 9742 7d0c dc42
9f40 efb0 0f00 4fb0 0402 ff0c fc42 ecb0
ff00 0e60 ce42 ef0c ed0d 7f0d 1962 49b1
0001 eb18 0c60 5a00 5a00
""".replace(' ','').replace('\n','').decode('hex') # 0x7d6
B = map(ord, B[:256])

for i in range(256):
    m[i] = i

j = 0
for i in range(256):
    k = m[i]
    j = (j + m[i] + A[i%16]) & 0xff
    m[i] = m[j]
    m[j] = k

j = 0
s = ""
for r6 in range(2,0x28):
    i = (r6 - 1) & 0xff

    k = m[i]
    j = (j + m[i]) & 0xff
    m[i] = m[j]
    m[j] = k

    k = (k + m[i]) & 0xff
    print r6, B[i] ^ m[k], s
    s += chr(B[i] ^ m[k])

```

The flag is `32C3_theres_an_arm_next_to_the_cpu`.

