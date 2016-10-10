---
layout: post
title: HITCON CTF 2016 Quals - MixerBox
category: writeup
---

Linux x86 ELF Reverse challenge.

> Mixed-arch, mixerbox

## Mixed-arch?

Why is this mixed-arch? There are these instructions everywhere.

```
  ...
  push 0x33
  call change_arch();
  call f();
  call restore_arch();
  ...

change_arch:
  retf

restore_arch:
  mov [ebp+4], 0x23
  retf
```

`retf` instruction pops two numbers, return address and `cs` segment register. According to [here](http://wiki.osdev.org/X86-64#Long_Mode) and [here](http://stackoverflow.com/a/32384358), setting `cs=0x23` puts the CPU into x86 mode, and setting `cs=0x33` puts the CPU into x86-64 mode (long mode). So the interpretation of the machine code differs before and after `retf`.

x86 and x86-64 assemblies are not so much different. So there was no big problem reading the code with 32-bit IDA. But some functions were cannot be disassembled so I used 64-bit IDA for those functions.

## Static analysis

The program's content is summarized as follows:

1. It takes max 64 character input from stdin
2. It creates 16 x 16 integer matrix from rand(). It uses fixed number 0xb7a4378e for srand().
3. Input bytes are xor'd to some of the matrix elements.
3. Run six different loops to manipulate the matrix.
4. Checks if the resulting matrix is equal to the answer.

Each loop takes a few rand() numbers and pass them as arguments to a mixing function along with the matrix itself. Loops are quite complicated. So I also used dynamic analysis to save time.

![mixedbox1.png](/assets/2016/10/mixedbox1.png)

## Debugging environment

First I tried to use DynamoRio to see the matrix content inside loop. But this failed because of the architecture mismatch. I cannot use 64-bit version of the tool,  because the binary is ELF32. But then 32-bit version of the tool crashes while executing 64-bit portion.

So I used plain gdb. I set breakpoints to start of each loop. I also defined gdb commands so that everytime I press 'c', the program continues until next breakpoint AND dumps stack memory for the 16x16 matrix.

```
b *0x80490a0
b *0x80490F0
b *0x8049150
b *0x8049200
b *0x8049260
b *0x80492C0
# stack offset is fixed inside gdb.
set $start = 0xffffd17c
set $end = ($start + 0x400)
define r
    run < in
    dump memory ./dump $start $end
end
define c
    continue
    dump memory ./dump $start $end
end
r
```

This dump file is displayed using this python script. The script monitors the dump file for any change, and display the modified part of the matrix.

```py
import struct
import os
import time
import subprocess

a = [0]*256
old_hash = 0
while True:
    time.sleep(1)
    new_hash = subprocess.check_output(['sha1sum', 'dump']).split()[0]
    if new_hash == old_hash:
        continue
    else:
        old_hash = new_hash

    os.system('clear')
    b = [0]*256
    with open('dump','rb') as f:
        for i in range(256):
            b[i] = struct.unpack("<I", f.read(4))[0]

    for i in range(256):
        content = "%8d" % (b[i])
        if b[i] != a[i]:
            print ("\033[1;35m%s\033[0m" % content),
        else:
            print ("%s" % content),
        a[i] = b[i]
        if i % 16 == 15:
            print
```

With these, I could easily identify operations such as row-swap, column-rotate, etc.

![mixedbox2.png](/assets/2016/10/mixedbox2.png)

<center><i>Example output showing a column-swap operation.</i></center>

## Loops

The loops are following:

1. Swap two random columns
2. Rotate columns by random amount
3. Matrix multiplication on random 2x2 submatrix by random 4 values
4. Swap two random rows
5. Rotate columns by random amount
6. Complicated row-swaps and column-swaps that actually results in changes in a cross-shaped region.

The loop 3 had this tricky code chunk. It took us quite long to figure out the meaning.

```asm
mov r12, 0x8697B200E286775B
mov     rax, r11
imul    r12
add     rdx, r11
mov     rax, rdx
shr     rax, 0x3F
sar     rdx, 0x17
add     rdx, rax
imul    rax, rdx, 0xF375F1
sub     r11, rax
```

This code actually calculates `r11 % 0xF375F1`.

## Solution

I implemented the inverse operation for each loops and calculated the correct initial matrix value. From this, I could recover the flag.

```py
import copy
from Crypto.Util.number import inverse

with open('random.txt', 'r') as f:
    r = map(int, f.read().splitlines())
r = r[::-1]
s = []
def rand():
    x = r.pop()
    s.append(x)
    return x
def rrand():
    return s.pop()

def dump(mat):
    for i in range(16):
        for j in range(16):
            print "%8d" % mat[i][j],
        print
    print

mat = [
        [2186, 1587, 1500, 2015, 2359,  845, 1090, 2102, 3853, 1577,  745, 2004,  868, 2621,   37, 3654],
        [1099, 1975, 1656, 1048, 2314,  526, 2417, 2679, 2059, 1961, 1039, 1467,  644,  642, 2389, 2830],
        [2229, 3889,  749,  493,  639, 1839, 2595,  396, 3416, 3340, 2400,  188, 1866, 2437, 3843, 2965],
        [ 317, 1403, 4013, 2631, 1929, 2335, 1214, 3988,  200, 2254, 1360,  844, 2896, 3749, 3674, 1029],
        [3542,  327, 1522,   85, 2166,   22,  481, 1486, 3362, 2881, 1675, 1132, 1223, 1422,    2, 1540],
        [2825, 4015,   75,  658, 2254, 1289,  551, 2454, 3543, 1911, 3298, 2343, 1564, 2876, 3373, 1010],
        [3203,  799, 1096, 1273,  821, 1577, 2760,   88,  363,  339, 1220, 1586, 1761, 1222, 3126,  490],
        [1142, 3201, 1148, 3396,  394, 1699, 1755, 3938, 3610,  957, 2185, 1078, 3834, 1462, 2089, 2941],
        [2262, 3185,  119, 3083,  666, 2879, 3171, 1029, 3218,  296, 2615,  883, 1518, 1645, 1373, 2660],
        [ 750, 2521, 1961, 1145,  125, 3716,  987, 3735,  577, 3172,  718,  315,  539, 2807, 3257, 2801],
        [1896, 3376, 1788, 2562, 2159,  864, 3592, 1281, 1160, 2111, 2164, 2678, 3757, 3537, 1243,  411],
        [1962, 3204, 1556, 2087, 2824, 2543, 1727, 3401, 1620, 2445, 3717, 2159, 1156, 2878,  864, 3052],
        [2158, 2652, 1518,  221, 3516, 1014, 1502,  580, 3126, 3666, 3259, 2787, 3107,  406, 3198,  973],
        [3610,  659, 3061, 2338, 3202,  692, 1643,  726, 3137, 1264, 2885,  197,   46, 3749, 3249, 2204],
        [2306,  671, 2425, 1726, 1686, 3927, 2307,  716, 3497, 1470, 3503, 2508, 1876, 2605, 3482, 1390],
        [3264, 2447, 3728, 2371, 3139, 1275, 3097, 2180, 2540, 1887, 2377, 2586, 1540, 1530,  695, 3846]
        ]
empty = copy.deepcopy(mat)

ans_linear = [
        0x25C05B, 0x0D27801, 0x36D906, 0x223FB3, 0x9D561D, 0x1CBE95,
        0x0D8A1CE, 0x9E8032, 0x166DFA, 0x0C2B9E6, 0x68F064, 0x57E959,
        0x0C09526, 0x13BDF3, 0x0EDEF66, 0x1E454E, 0x86DE88, 0x6F8AEF,
        0x0E015F0, 0x91CEE3, 0x0ED484C, 0x18F5D0, 0x0BD3071, 0x0E50A10,
        0x0B7E75, 0x986BA7, 0x0EE8851, 0x4C5592, 0x16AE75, 0x0C5D5B7,
        0x0DFE001, 0x0CF87C, 0x0C12884, 0x93BA6D, 0x7FB055, 0x8B6CC9,
        0x0A76707, 0x536190, 0x0C182B2, 0x0F2FC7A, 0x78291E, 0x0E2EB8F,
        0x23546A, 0x396549, 0x0A88F10, 0x0B82BEB, 0x9BBD81, 0x1CD0CB,
        0x0A87DE5, 0x0D64991, 0x1644D, 0x0CA9AC5, 0x0D7D70F, 0x953ED7,
        0x6D4D49, 0x0A39A69, 0x0AB6E5A, 0x204130, 0x669B9A, 0x87CC2D,
        0x293DD7, 0x1BAF08, 0x0EDF0BB, 0x2E7031, 0x0DD3967, 0x0A482B1,
        0x36E07, 0x0B7F344, 0x143BA, 0x9CCC8D, 0x2FE015, 0x2D6F4D,
        0x47114C, 0x29EC61, 0x7CC74, 0x0C48F62, 0x2710DE, 0x0CBE4D4,
        0x0E7A895, 0x710BF3, 0x9A63BE, 0x88103B, 0x0B67505, 0x527B5E,
        0x48B446, 0x1D0257, 0x3D7218, 0x0AA54FC, 0x0DA7BD2, 0x0B494F3,
        0x0F2CEFD, 0x27826D, 0x838279, 0x0E32217, 0x27D99C, 0x921A51,
        0x6B8AFC, 0x297029, 0x347B33, 0x354A49, 0x2B1DCE, 0x0DD3127,
        0x60B679, 0x22C930, 0x326E86, 0x0CBA10B, 0x41F50F, 0x900C54,
        0x0DC46A9, 0x0E6985A, 0x958DD, 0x2412B7, 0x0ED3CD4, 0x3F1BFD,
        0x87FF4A, 0x0D2CD61, 0x3ABCB0, 0x114A8F, 0x2EF473, 0x1692D1,
        0x0EA13F3, 0x45F114, 0x89B1A5, 0x0ADEB5B, 0x8365A7, 0x58B09D,
        0x0AAEB8E, 0x0DBADE, 0x0BD6CF4, 0x864FC1, 0x712AD9, 0x76D15,
        0x0C55D0C, 0x5A1A57, 0x82A021, 0x942B4F, 0x8C8E6F, 0x7F8085,
        0x90ED83, 0x0F3A94, 0x1298F0, 0x48F126, 0x0E14823, 0x0C5607,
        0x0DDA0FD, 0x3ED7A2, 0x1E4985, 0x3F366A, 0x0ACFFC5, 0x4D840B,
        0x0B2AB35, 0x5B3FFC, 0x2E8565, 0x473E7C, 0x33BAF, 0x0B350D4,
        0x1A868F, 0x6C5939, 0x8CF51A, 0x0AE6FB5, 0x6F9E32, 0x0A70523,
        0x17C0F5, 0x487092, 0x88EF2C, 0x3C40BF, 0x0A1B3B, 0x0AE8AF1,
        0x0BCB6FB, 0x0DEBCF6, 0x0CCD481, 0x0E98B86, 0x0BD0EE1, 0x34C6DE,
        0x0F29CF2, 0x68FAC7, 0x507E2B, 0x0DFFB94, 0x0BA3FFE, 0x9B17B2,
        0x76FB2, 0x82DBFF, 0x0B93361, 0x0EFB947, 0x149647, 0x0B4DAB8,
        0x57099D, 0x659458, 0x2E7FAE, 0x5625D8, 0x50B3A8, 0x36A16E,
        0x9D8B05, 0x0DD109D, 0x0CABA62, 0x0DB2B, 0x0DA6E0A, 0x0EDBA3C,
        0x51EE08, 0x0AC57BA, 0x667392, 0x4E7598, 0x0B2C165, 0x0B2875B,
        0x0AD1B17, 0x0B0EF80, 0x282706, 0x44373C, 0x0BFB823, 0x351A8,
        0x330C78, 0x0EBAF3F, 0x26725B, 0x95C0E7, 0x0C8AB9F, 0x647ABC,
        0x0C62714, 0x81396B, 0x0CF738B, 0x66F5F0, 0x0CC304C, 0x0E4CB60,
        0x479750, 0x88E2D6, 0x0BA75D4, 0x301A4C, 0x90220A, 0x310DBF,
        0x0B6BBC, 0x2B452A, 0x538A32, 0x12FE4, 0x0D576BD, 0x0BB47ED,
        0x0F1F231, 0x88428A, 0x6B4D26, 0x4852AC, 0x6ED3B9, 0x756EAA,
        0x0F4D67, 0x78B857, 0x0B6E7F6, 0x0ABFC17, 0x0AE4CEE, 0x0B8755A,
        0x8A9D91, 0x61D90E, 0x0BAF895, 0x0C3C7D3, 0x76A4B3, 0x3460D1,
        0x7D7AAB, 0x0AF56B9, 0x279CDD, 0x12E83A
        ]

ans = [[0]*16 for _ in range(16)]
for i in range(256):
    ans[i/16][i%16] = ans_linear[i]

def colswap(mat, x, y):
    for i in range(16):
        mat[i][x], mat[i][y] = mat[i][y], mat[i][x]

def colrot(mat, n):
    n = n % 16
    m = copy.deepcopy(mat)
    for i in range(16):
        for j in range(16):
            m[i][j] = mat[i][(j + n) % 16]
    return m

def mult(mat, i, j, r1, r2, r3, r4):
    r1 = r1 % 0xf375f1
    r2 = r2 % 0xf375f1
    r3 = r3 % 0xf375f1
    r4 = r4 % 0xf375f1
    t1 = r1 * mat[i][ j  ] + r2 * mat[i+1][ j  ]
    t2 = r1 * mat[i][ j+1] + r2 * mat[i+1][ j+1]
    t3 = r3 * mat[i][ j  ] + r4 * mat[i+1][ j  ]
    t4 = r3 * mat[i][ j+1] + r4 * mat[i+1][ j+1]
    mat[i  ][ j  ] = (t1 % 0xf375f1) & 0xffffffff
    mat[i  ][ j+1] = (t2 % 0xf375f1) & 0xffffffff
    mat[i+1][ j  ] = (t3 % 0xf375f1) & 0xffffffff
    mat[i+1][ j+1] = (t4 % 0xf375f1) & 0xffffffff

def rev_mult(mat, i, j, r1, r2, r3, r4):
    r1 = r1 % 0xf375f1
    r2 = r2 % 0xf375f1
    r3 = r3 % 0xf375f1
    r4 = r4 % 0xf375f1
    det = r1*r4 - r2*r3
    t1 = r4 * mat[i][ j  ] - r2 * mat[i+1][ j  ]
    t2 = r4 * mat[i][ j+1] - r2 * mat[i+1][ j+1]
    t3 = -r3 * mat[i][ j  ] + r1 * mat[i+1][ j  ]
    t4 = -r3 * mat[i][ j+1] + r1 * mat[i+1][ j+1]
    def g(x):
        return (x * inverse(det, 0xf375f1)) % 0xf375f1

    mat[i  ][ j  ] = g(t1) & 0xffffffff
    mat[i  ][ j+1] = g(t2) & 0xffffffff
    mat[i+1][ j  ] = g(t3) & 0xffffffff
    mat[i+1][ j+1] = g(t4) & 0xffffffff

def rowswap(mat, x, y):
    for i in range(16):
        mat[x][i],mat[y][i] = mat[y][i],mat[x][i]

def cross(mat, x, y):
    def sub_9d0(mat, a, b, c, d, n):
        while n > 0:
            n -= 1
            rowswap(mat, a, c)
            colswap(mat, b, d)
            a+=1; b+=1; c+=1; d+=1

    def sub_eb0(mat, x, y):
        sub_9d0(mat, x, y, x+1, y+1, 1)

    def sub_380(mat, x, y):
        sub_9d0(mat, x, y, x+2, y+2, 2)
        sub_eb0(mat, x, y)
        sub_eb0(mat, x+2, y)
        sub_eb0(mat, x+2, y+2)
        sub_eb0(mat, x, y+2)

    sub_9d0(mat, x, y, x+4, y+4, 4)
    sub_380(mat, x, y)
    sub_380(mat, x+4, y)
    sub_380(mat, x+4, y+4)
    sub_380(mat, x, y+4)

def rev_cross(mat, x, y):
    def rev_9d0(mat, a, b, c, d, n):
        a+=n;b+=n;c+=n;d+=n;
        while n > 0:
            a-=1; b-=1; c-=1; d-=1
            n -= 1
            colswap(mat, b, d)
            rowswap(mat, a, c)
    def rev_eb0(mat, x, y):
        rev_9d0(mat, x, y, x+1, y+1, 1)
    def rev_380(mat, x, y):
        rev_eb0(mat, x, y+2)
        rev_eb0(mat, x+2, y+2)
        rev_eb0(mat, x+2, y)
        rev_eb0(mat, x, y)
        rev_9d0(mat, x, y, x+2, y+2, 2)

    rev_380(mat, x, y+4)
    rev_380(mat, x+4, y+4)
    rev_380(mat, x+4, y)
    rev_380(mat, x, y)
    rev_9d0(mat, x, y, x+4, y+4, 4)

def forward():
    global mat
    for i in range(256):
        mat[i/16][i%16] = rand() & 0xfff

    for i in range(1000):
        colswap(mat, rand() % 16, rand() % 16)

    for i in range(1000):
        mat = colrot(mat, rand() % 77)

    for i in range(10000):
        r1 = rand()
        r2 = rand()
        r3 = rand()
        r4 = rand()
        r5 = rand()
        r6 = rand()
        mult(mat, r2 % 15, r5 % 15, r3, r6, r1, r4)

    for i in range(1000):
        rowswap(mat, rand()%16, rand()%16)

    for i in range(1000):
        mat = colrot(mat, rand() % 77)

    for i in range(1000):
        cross(mat, rand() % 9, rand() % 9)

def backward():
    global mat
    for i in range(1000):
        a, b = rrand()%9, rrand()%9
        rev_cross(mat, b, a)

    for i in range(1000):
        r = rrand() % 77
        r = (16 - r) % 16
        mat = colrot(mat, r)

    for i in range(1000):
        a = rrand()%16
        b = rrand()%16
        rowswap(mat, b, a)

    for i in range(10000):
        r6 = rrand()
        r5 = rrand()
        r4 = rrand()
        r3 = rrand()
        r2 = rrand()
        r1 = rrand()
        rev_mult(mat, r2 % 15, r5 % 15, r3, r6, r1, r4)

    for i in range(1000):
        r = rrand() % 77
        r = (16 - r) % 16
        mat = colrot(mat, r)
    for i in range(1000):
        colswap(mat, rrand() % 16, rrand() % 16)

forward()
mat = ans
backward()
print'----------------------'

xorseq = [
        (0, 0), (0, 1), (1, 0), (2, 0), (1, 1), (0, 2), (0, 3), (1, 2), (2, 1), (3, 0), (4, 0), (3, 1), (2, 2), (1, 3),
        (0, 4), (0, 5), (1, 4), (2, 3), (3, 2), (4, 1), (5, 0), (6, 0), (5, 1), (4, 2), (3, 3), (2, 4), (1, 5), (0, 6), (0, 7), (1, 6), (2, 5),
        (3, 4), (4, 3), (5, 2), (6, 1), (7, 0), (8, 0), (7, 1), (6, 2), (5, 3), (4, 4), (3, 5), (2, 6), (1, 7), (0, 8), (0, 9),
        (1, 8), (2, 7), (3, 6), (4, 5), (5, 4), (6, 3), (7, 2), (8, 1), (9, 0), (10, 0), (9, 1), (8, 2), (7, 3), (6, 4),
        (5, 5), (4, 6), (3, 7), (2, 8), (1, 9)]

dump(empty)
dump(mat)
s = ''
for x,y in xorseq:
    s += chr(empty[x][y] ^ mat[x][y])
print s
```

The flag is `hitcon{____0n3_4Pp___t0_pL4Y__tH3m___4lL!!!_!}`.

This was fun! thx to HITCON for great challenge.
