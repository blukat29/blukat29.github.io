---
layout: post
title: SECCON CTF 2015 - Individual Elebin
category: writeup
---

> Execute all ELF files

We are given 11 ELF binaries, for all different architectures.

```
$ file *
10.bin:  ELF 32-bit LSB  executable, ARM, version 1, statically linked, stripped
11.bin:  ELF 32-bit MSB  executable, MIPS, MIPS-I version 1 (SYSV), statically linked, stripped
1.bin:   ELF 32-bit LSB  executable, Intel 80386, version 1 (FreeBSD), statically linked, stripped
2.bin:   ELF 32-bit MSB  executable, MC68HC11, version 1 (SYSV), statically linked, stripped
3.bin:   ELF 32-bit LSB  executable, NEC v850, version 1 (SYSV), statically linked, stripped
4.bin:   ELF 32-bit MSB  executable, Renesas M32R, version 1 (SYSV), statically linked, stripped
5.bin:   ELF 64-bit MSB  executable, Renesas SH, version 1 (SYSV), statically linked, stripped
6.bin:   ELF 32-bit MSB  executable, SPARC version 1 (SYSV), statically linked, stripped
7.bin:   ELF 32-bit LSB  executable, Motorola RCE, version 1 (SYSV), statically linked, stripped
8.bin:   ELF 32-bit LSB  executable, Axis cris, version 1 (SYSV), statically linked, stripped
9.bin:   ELF 32-bit LSB  executable, Atmel AVR 8-bit, version 1 (SYSV), statically linked, stripped
```

There are number of ways to deal with this problem

## 1. Static analysis

All of them can be opened and disassembled with IDA, without any additional effort. But studying each architecture and understanding assemblies will not be done in 24 hours. We abandoned this approach.

## 2. Building cross-compiler toolchain

We can build GNU cross-compiler toolchain to get simulator for each target. Tutorials can be found in many places, <http://www.ifp.illinois.edu/~nakazato/tips/xgcc.html> and <https://www.linux-mips.org/wiki/Toolchains> provide concise walkthrough. You need not to install gcc to just execute a binary. Having binutils should be enough.

But building tools for 10 architecture (excluding x86) takes so long.

## 3. Using pre-built image

I remembered a multi-architecture development environment that our team used in SECCON 2014 Finals. The tool can be found at <http://kozos.jp/vmimage/burning-asm.html>. It's a CentOS VM image for Oracle VirtualBox(.ova). It contains cross-compiler suites for various architectures.

```
$ /usr/local/cross/bin/m32r-elf-run 4.bin
N
```

## 4. Flag

Combining the output of each binary, we have the flag `SECCON{AaABiN1234567890abcdefBDFHJLNPAW3a5d37a38a0d28faAq}`.

