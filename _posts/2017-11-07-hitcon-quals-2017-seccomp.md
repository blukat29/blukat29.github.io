---
layout: post
title: HITCON CTF Quals 2017 - Seccomp
category: writeup
---

ELF x64 reversing challenge.

### 1. The main function

It is a small program. This program hides its core logic inside the seccomp syscall filter rule, and requires us to figure out the correct syscall arguments.

The filter rules stored at 0x201020 can be easily decoded using [seccomp-tools](https://github.com/david942j/seccomp-tools). I have used [bpftools](https://github.com/cloudflare/bpftools) for the decoding purpose, but outputs from seccomp-tools are more human-readable.

```c
int __cdecl main(int argc, const char **argv, const char **envp)
{
  int result; // eax@7
  __int64 v4; // rcx@7
  signed int i; // [rsp+Ch] [rbp-54h]@1
  sock_fprog v6; // [rsp+10h] [rbp-50h]@1
  _QWORD v7[7]; // [rsp+20h] [rbp-40h]@1
  __int64 v8; // [rsp+58h] [rbp-8h]@1

  v8 = *MK_FP(__FS__, 40LL);
  v6.len = 4059;
  v6.filter = &filter_201020;
  memset(v7, 0, 0x30uLL);
  for ( i = 0; i <= 4; ++i )
    _isoc99_scanf("%llu", &v7[i]);
  prctl(PR_SET_NO_NEW_PRIVS, 1LL, 0LL, 0LL, 0LL);
  if ( prctl(PR_SET_SECCOMP, 2LL, &v6) )
  {
    perror("prctl");
    exit(1);
  }
  syscall(0x1337LL, v7[0], v7[1], v7[2], v7[3], v7[4], v7[5]);
  printf("Excellent! flag: hitcon{""%s""}\n", v7);
  result = 0;
  v4 = *MK_FP(__FS__, 40LL) ^ v8;
  return result;
}
```

### 2. Reverse the filter

The filter is 4000 lines long. I first skimmed through the instructions and discovered recurring patterns.

Below piece of code splits a 64-bit argument into four 16-bit integers and store them at M[0]..M[3]. Note that BPF has following 32-bit registers:
- `A`: The most frequently used register.
- `X`: Also frequently used register.
- `M[0]` .. `M[15]`: Sixteen index-addressed registers, sometimes referred as "mem".

```
 0003:  A = args[0]
 0004:  X = A
 0005:  A &= 0xffff
 0006:  mem[3] = A
 0007:  A = X
 0008:  A >>= 16
 0009:  mem[2] = A
 0010:  A = args[0] >> 32
 0011:  X = A
 0012:  A &= 0xffff
 0013:  mem[1] = A
 0014:  A = X
 0015:  A >>= 16
 0016:  mem[0] = A
```

This code calculates `(M[0] * 0x6761) % 65537` with some edge case handling. With the edge cases removed, this operation is invertible.

```
 0017:  A = mem[0]
 0018:  if (A != 0) goto 0020
 0019:  A = 65536
 0020:  A *= 0x6761
 0021:  X = A
 0022:  A /= 0x10001
 0023:  A *= 0x10001
 0024:  A = -A
 0025:  A += X
 0026:  if (A != 65536) goto 0028
 0027:  A = 0
 0028:  mem[0] = A
```

And this code adds two 16-bit integers.

```
 0033:  A = mem[2]
 0034:  A += 0x5f65
 0035:  A &= 0xffff
 0036:  mem[2] = A
```

This is how resulting values are checked.

```
 0797:  X = 4919
 0798:  A = mem[3]
 0799:  A ^= X
 0800:  if (A == 2695) goto 0802
 0801:  return KILL
 0802:  A = mem[2]
 0803:  A ^= X
 0804:  if (A == 6003) goto 0806
 0805:  return KILL
 0806:  A = mem[1]
 0807:  A ^= X
 0808:  if (A == 45409) goto 0810
 0809:  return KILL
 0810:  A = mem[0]
 0811:  A ^= X
 0812:  if (A == 44702) goto 0814
 0813:  return KILL
```

There are a few more patterns such as register swap and XOR.


### 3. Simplify the filter

I simplified the filter program with a pattern matching algorithm.

```py
import re

def get_opcode(code):
    if ' = ' in code: return 'mov'
    elif '+=' in code: return 'add'
    elif '&=' in code: return 'and'
    elif '^=' in code: return 'xor'
    elif '>>=' in code: return 'shr'
    elif '*=' in code: return 'mul'
    elif '/=' in code: return 'div'
    elif 'if' in code: return 'if'
    elif 'return' in code: return 'ret'
    else: return 'other'

all_lines = []
all_ops = []
content = open('disas').read()
content = re.sub('mem\[(\d)\]', 'M\\1', content)
for idx, line in enumerate(content.splitlines()):
    line = line[8:]
    op = get_opcode(line)
    all_lines.append(line)
    all_ops.append(op)
return all_lines, all_ops

idx = 0
irs = []
while idx < len(all_lines):
    lines = all_lines[idx:idx+20]
    ops = all_ops[idx:idx+20]

    if ops[:14] == 'mov mov and mov mov shr mov mov mov and mov mov shr mov'.split():
        irs.append(('INPUT',))
        idx += 14
    elif ops[:12] == 'mov if mov mul mov div mul mov add if mov mov'.split():
        src = lines[0].split()[-1]
        dst = lines[11].split()[0]
        num = int(lines[3].split()[-1], 16)
        irs.append(('MUL', dst, src, num))
        idx += 12
    elif ops[:5] == 'mov mov add and mov'.split():
        src1 = lines[0].split()[-1]
        src2 = lines[1].split()[-1]
        dst = lines[4].split()[0]
        irs.append(('ADDV', dst, src1, src2))
        idx += 5
    # (continued
```

This script produces following output.

```
// Repeat 5 times for each argument
    ('INPUT',)

    // Repeat 8 times with different numbers
        ('MUL', 'M0', 'M0', 26465)
        ('ADDC', 'M1', 'M1', 27750)
        ('ADDC', 'M2', 'M2', 24421)
        ('MUL', 'M3', 'M3', 27489)
        ('XORV', 'M4', 'M0', 'M2')
        ('XORV', 'M5', 'M1', 'M3')
        ('MUL', 'M4', 'M4', 26207)
        ('ADDV', 'M5', 'M4', 'M5')
        ('MUL', 'M5', 'M5', 24927)
        ('ADDV', 'M4', 'M4', 'M5')
        ('XORV', 'M0', 'M0', 'M5')
        ('XORV', 'M1', 'M1', 'M4')
        ('XORV', 'M2', 'M2', 'M5')
        ('XORV', 'M3', 'M3', 'M4')
        ('SWAP', 'M1', 'M2')

    ('MUL', 'M0', 'M0', 6551)
    ('ADDC', 'M1', 'M1', 55642)
    ('ADDC', 'M2', 'M2', 55385)
    ('MUL', 'M3', 'M3', 38872)
    ('CHECK', 4919, [2695, 6003, 45409, 44702])
```

### 4. Find the flag

The argument checking routine is an 8-round encryption. One round looks like this:

```py
def mul(x, y):
    if x == 0: x = 65536
    x = (x * y) % 65537
    if x == 65536: x = 0
    return x
def add(x, y):
    return (x + y) & 0xffff

def forward(m, p):
    m0, m1, m2, m3 = m
    p0, p1, p2, p3, p4, p5 = p
    # p0..p6 are constant numbers appears in the code.

    # Step 1
    m0 = mul(m0, p0)
    m1 = add(m1, p1)
    m2 = add(m2, p2)
    m3 = mul(m3, p3)

    # Step 2
    m4 = m0 ^ m2
    m5 = m1 ^ m3

    # Step 3
    m4 = mul(m4, p4)
    m5 = add(m4, m5)
    m5 = mul(m5, p5)
    m4 = add(m4, m5)

    # Step 4
    m0 ^= m5
    m1 ^= m4
    m2 ^= m5
    m3 ^= m4

    # Step 5
    m1, m2 = m2, m1
    return (m0, m1, m2, m3)
```

It may look complicated because m4 and m5 are modified back and forth.

However, `m0 ^ m2` after step 4 is equal to `m0 ^ m2` after step 2, which is eventually equal to m4 after step 2. Similarly, we can find the m5 after step 2. Subsequently, we can write inverse round function.

```py
def inv_mul(x, y):
    if x == 0: x = 65536
    x = (x * modinv(y, 65537)) % 65537
    if x == 65536: x = 0
    return x
def inv_add(x, y):
    return (x - y) & 0xffff

def backward(m, p):
    m0, m1, m2, m3 = m
    p0, p1, p2, p3, p4, p5 = p

    m1, m2 = m2, m1

    m4 = m0 ^ m2
    m5 = m1 ^ m3
    m4 = mul(m4, p4)
    m5 = add(m4, m5)
    m5 = mul(m5, p5)
    m4 = add(m4, m5)

    m0 ^= m5
    m1 ^= m4
    m2 ^= m5
    m3 ^= m4

    m0 = inv_mul(m0, p0)
    m1 = inv_add(m1, p1)
    m2 = inv_add(m2, p2)
    m3 = inv_mul(m3, p3)
    return (m0, m1, m2, m3)
```

Find the correct arguments `args[0]`..`args[4]` to get the flag.

`hitcon{w0w_y0u_are_Master-0F-secc0mp///>_w_<///}`

