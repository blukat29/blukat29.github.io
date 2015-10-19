---
layout: post
title: HITCON Quals 2015 - Risky
category: writeup
---

Risky is a RISC-V revserse task.

## 1. Install tools

When I opened the binary in IDA, it showed `Unknown CPU [243]`. [ELF Header](http://www.sco.com/developers/gabi/latest/ch4.eheader.html) says that architecture #243 is RISC-V.

Next I installed riscv toolchain from <https://github.com/riscv/riscv-tools>. Installation took quite long but went well.

Now we have `readelf` and `objdump` for riscv.

## 2. Extract data

```
$ riscv-tools/bin/riscv64-unknown-elf-readelf -h risky
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           RISC-V
  Version:                           0x1
  Entry point address:               0x800900
    ...
```

```
# code sections
$ riscv-tools/bin/riscv64-unknown-elf-objdump -d risky > asm.txt
# data sections
$ riscv-tools/bin/riscv64-unknown-elf-objdump -s risky > data.txt
```

## 3. About RISC-V architecture

RISC-V is another RISC architecture. ISA documentation can be found at <http://riscv.org/download.html>

It was overall similar to MIPS. It has 32 registers, arguments are passed through registers, and it takes 2 instructions to load 32-bit constant. Below are notable points.

Assembly syntax

```
op  rd, rs
op  rd, rs1, rs2
op  rd, imm
op  rs1, rs2, addr
```

Loading 32-bit constant

```
lui r, A
addi r, r, B    # r = (A << 12) + B
```

Register usage and calling conventions

```
  index   name        usage                    saves
---------+-----+-----------------------------+-------
x0        zero  Hard-wired zero
x1        ra    Return address                Caller
x2        s0/fp Saved register/frame pointer  Callee
x3-13     s1-11 Saved registers               Callee
x14       sp    Stack pointer                 Callee
x15       tp    Thread pointer                Callee
x16-17    v0-1  Return values                 Caller
x18-25    a0-7  Function arguments            Caller
x26-30    t0-4  Temporaries                   Caller
x31       gp    Global Pointer
```

`jal` is "Jump and Link". It's like `call` in x86.

Global data are referenced by relative address from `gp`, which is set at the start of program.

This is ELF64 program. All registers are 64-bit. Opcodes have suffixes if they deal with different size of data. `w` means 32-bit word, `b` means 8-bit byte, `u` means unsigned. (e.g. `lw` loads a 32-bit int. `lbu` loads an 8-bit unsigned byte)

## 4. Reverse overall code

From ELF header, we know that the entry point is `800900`.

`gp` is set to `0x802648`.  First argument (`a0`) is `800580`, which is the address of `main`.

```
_start:
  800900: 00002197            auipc gp,0x2
  800904: d4818193            addi  gp,gp,-696 # 802648
  800908: 00050793            mv  a5,a0
  80090c: 00000517            auipc a0,0x0
  800910: c7450513            addi  a0,a0,-908 # 800580
  800914: 00013583            ld  a1,0(sp)
  800918: 00810613            addi  a2,sp,8
  80091c: ff017113            andi  sp,sp,-16
  800920: 00000697            auipc a3,0x0
  800924: 11868693            addi  a3,a3,280 # 800a38
  800928: 00000717            auipc a4,0x0
  80092c: 1a070713            addi  a4,a4,416 # 800ac8
  800930: 00010813            mv  a6,sp
  800934: c0dff06f            j 800540 <__libc_start_main@plt>
```

This is first part of `main` where it receives a line of string and checks its format.

```c
// .sdata:0x801e48
unsigned long long int mask = 0x3ffffff01ff9ULL;

int main()
{
  char* line = NULL; // sp+16, a5
  size_t len = 0;    // sp+8

  puts("The flag is protected by my RISKY machine...");
  getline(&line, &len, 0x801e60); // .bss start

  a0 = &line;
  a4 = line[4];
  if ('-' != a4) {
bad: // 8005d8
    puts("SSSssSSSsssSSssS...");
    return;
  }

  if (a4 != line[9] || a4 != line[14] || a4 != line[19]) goto bad;
  if (line[24] != '\n') goto bad;

  char* a3 = line;
  while (a3 - line >= n)
  {
    char a4 = (*a3 - 45) & 0xFF;
    if (line[19] < a4) goto bad;
    if ((mask >> a4) & 1 == 0) goto bad;
    a3++;
  }

// 80066c:
```

So the input format is `XXXX-XXXX-XXXX-XXXX-XXXX` where `X` must be one of `-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ`.

## 5. Reverse key checker

Rest of the `main` is the part that checks the input.

```c
// 80066c:
  s0 = *(int*)&line[20];
  s1 = *(int*)&line[10];
  s2 = *(int*)&line[5];
  s3 = *(int*)&line[0];
  s5 = *(int*)&line[15];
  printf("Verifying"); fflush(0);
  s6 = s1 * s5;

  if ((s3 * s2) + s6 + s0 != 0x181a9c5f) goto bad;
  if ((s3 * s1) + (s2 + s0) != 0x2deacccb) goto bad;
  if ((s3 + s2 + s1 + s5 + s0) != 0x8e2f6780) goto bad;
  if ((s3 + s5) * (s2 + s1 + s0) != 0xb3da7b5f) goto bad;
  if ((s2 + s1 + s0) != 0xe3b0cdef) goto bad;
  if (s3 * s0 != 0x4978d844) goto bad;
  if (s2 * s1 != 0x9bcd30de) goto bad;
  if ((s2 * s1 * s6 * s0) != 0x41c7a3a0) goto bad;
  if (s6 != 0x313ac784) goto bad;

// 80080c:
  v32 = 0x2c280d2f;
  v36 = 0x38053525;
  v40 = 0x6b5c2a24;
  v44 = 0x27542728;
  v48 = 0x2975572f;
  v56 = s3;
  v60 = s2;
  v64 = s1;
  v68 = s5;
  v72 = s0;
  v28 = 0;
  strcpy(&v80, "hitcon{");
  printf("\nGenerating flag"); fflush(0);

// 800880
  s0 = 0;
  s1 = 20;
  do {
    a4 = *(sp + 32 + s0);
    a5 = *(sp + 56 + s0);
    s0 += 4;
    v24 = a4 ^ a5;
    char* end = &v80 + strlen(&v80);
    a0 = stpcpy(end, &v24);
  } while (s0 != s1);

  a0[0] = '}';
  a0[1] = '\0';

  printf("%s", &v80);
}
```

It interpretes the five `XXXX` as little-endian 32-bit integers. Then it checks 9 equations on those numbers. If it passes all checks, then those values are XORed with some constant, which becomes the flag.

## 6. Solve equations

Rewrite equations for readability.

```
AAAA-BBBB-CCCC-DDDD-EEEE

A = s3; B = s2; C = s1; D = s5; E = s0

1: AB + CD + E == 0x181a9c5f
2: AC + B + E == 0x2deacccb
3: A + B + C + D + E == 0x8e2f6780
4: (A + D)(B + C + E) == 0xb3da7b5f
5: B + C + E == 0xe3b0cdef
6: AE == 0x4978d844
7: BC == 0x9bcd30de
8: BC*CD*E == 0x41c7a3a0
9: CD == 0x313ac784
```

We can solve them step by step. For example, from equations 7, 8, 9, we can find E. I simply brute forced 32-bit. There are number of solutions, but only one is in range `[0-9A-Z]{4}`.

```
void main()
{
  unsigned int cdu = 0x313ac784;
  unsigned int bcu = 0x9bcd30de;
  unsigned int eu = 1;
  while (eu != 0)
  {
    int x = ((int)cdu) * ((int)bcu) * ((int)eu);
    if (x == 0x41c7a3a0)
      printf("found %x\n", eu);
    eu ++;
  }
}
```

This way, we can find other values, too.

```
Brute for E in 7, 8, 9:
    0x9bcd30de * 0x313ac784 * E = 0x41c7a3a0
    => E = 0x4444364c "DD6L"

Brute for A in 6:
    A * 0x4444364c = 0x4978d844
    => A = 0x5949544b "YITK"

Calculate D from 5, 3:
    D = (A+B+C+D+E) - (B+C+E) - A
    => D = 0x51354546 "Q5EF"

Calculate AB from 1, 9:
    => AB = 0x181a9c5f - E - CD = 0xa29b9e8f

Brute for B from AB value:
    0x5949544b * B = 0xa29b9e8f
    => B = 0x4d354c4d "M5LM"

Calculate C from 5:
    C = 0xe3b0cdef - 0x4d354c4d - 0x4444364c
    => C = 0x52374b56 "R7KV"
```

So the correct input is `KTIY-ML5M-VK7R-FE5Q-L6DD`.

Finally, we xor this solution by the constants in code to get the flag: `hitcon{dYauhy0urak9nbavca1m}`


