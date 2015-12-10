---
layout: post
title: SECCON CTF 2015 - Remote GDB
category: writeup
---

Given an ELF binary `putskey` and a text file `log.txt`. As the title suggests, `log.txt` is a remote GDB command log.

## 1. Reverse binary

The binary is simple. It reads two inputs, `flag` and `enc` using `getc()` into buffers in .data section. Then it xors two string into `enc`, and prints the result. But we don’t know the data.

The location of first input buffer is `flag: 0x80d7300 ~ 0x80d7340`. Second input buffer is located at `rnd: 0x80d7340 ~ 0x80d7380`. Resulting data are stored at `enc: 0x80d7380 ~ 0x80d73c0`.

## 2. Parse log file

Remote GDB protocol is throughly documented at <https://sourceware.org/gdb/onlinedocs/gdb/Overview.html> and <https://sourceware.org/gdb/onlinedocs/gdb/Packets.html>.

First I focused on memory read command (`m`) because data are written in fixed locations. From this, content of `rnd` could be recovered:

```
65 6f 26 02 13 06 25 60 34 0b 27 3b 78 3a 26 00 39 4a 46 5d 3d 5e 58 36
```

Content of `flag` and `enc` did not appear in memory read commands. Instead, I found many repetitive breakpoint, continue and register (`g`) read command. I extracted `eax` of every register read command, hopefully contains the return value of `getc()`. Among bunch of numbers, I found the data that looks like `flag`.

```
36 2a 65 41 5c 48 5e 28 51 67 4b 54 3f 7e 64 50 4b 25 32 32 5e 31 34 4b
```

The answer is xor of two strings. `SECCON{HelloGDBProtocol}`.

