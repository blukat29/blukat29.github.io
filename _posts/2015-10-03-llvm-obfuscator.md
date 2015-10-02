---
layout: post
title: LLVM Obfuscator
category: reversing
---

홈페이지: <https://github.com/obfuscator-llvm/obfuscator/wiki>

LLVM Obfuscator는 LLVM으로 C/C++ 프로그램을 컴파일하는 과정에서 IR(Intermediate Representation) 수준의 난독화(Obfuscation)를 해주는 툴이다.

Control Flow Flattening, Instructions Substitution, Bogus Control Flow, 이 세 기법을 구현해 놓았다.

### 1. 설치 및 사용

<https://github.com/obfuscator-llvm/obfuscator/wiki/Installation> 를 따라하면 된다.

cmake 외에 특별한 dependency는 없는 듯 하다. 소스에 clang과 LLVM이 통째로 포함되어 있어서 빌드가 상당히 오래 걸린다. 최소 2~30분 정도는 생각해야 한다.

### 2. 간단한 테스트

아래의 엄청 짧은 C코드를 가지고 테스트해보았다.

```c
#include <stdio.h>

int main()
{
  char x[11];
  int i;
  for (i=0; i<10; i++)
  {
    if (i % 2 == 0)
      x[i] = 97 + i;
    else
      x[i] = 65 + i;
  }
  x[10] = 0;
  printf("%s\n", x);
}
```

### 3. Control Flow Flattening (CFF) 결과

<https://github.com/obfuscator-llvm/obfuscator/wiki/Control-Flow-Flattening>

Control-Flow-Flattening은 한 함수의 모든 basic block을 switch-case 한 개로 묶어서 for, if, while과 같은 control structure를 알아보기 어렵게 만드는 기법이다.

Codegate 2015 Quals의 guesspw문제에 CFF기법이 적용되어있었다.

```c
int __cdecl main(int argc, const char **argv)
{
  signed int v2; // eax@18
  signed int v3; // edx@21
  signed int v5; // [sp+48h] [bp-18h]@1
  signed int v6; // [sp+4Ch] [bp-14h]@1
  char v7[10]; // [sp+51h] [bp-Fh]@24
  char v8; // [sp+5Bh] [bp-5h]@28
  int v9; // [sp+5Ch] [bp-4h]@1

  v9 = 0;
  v6 = 0;
  v5 = -1055959067;
  do
  {
    while ( 1 )
    {
      while ( 1 )
      {
        while ( v5 <= -1055959068 )
        {
          if ( v5 == -1953331043 )
            v5 = -816333629;
        }
        if ( v5 > -902648344 )
          break;
        if ( v5 == -1055959067 )
        {
          v2 = -902648343;
          if ( v6 < 10 )
            v2 = 106188015;
          v5 = v2;
        }
      }
      if ( v5 <= -816333630 )
        break;
      if ( v5 > 106188014 )
      {
        switch ( v5 )
        {
          case 106188015:
            v3 = 1039917137;
            if ( !(v6 % 2) )
              v3 = 1045889936;
            v5 = v3;
            break;
          case 1039917137:
            v7[v6] = v6 + 65;
            v5 = -1953331043;
            break;
          case 1045889936:
            v7[v6] = v6 + 97;
            v5 = -1953331043;
            break;
        }
      }
      else if ( v5 == -816333629 )
      {
        ++v6;
        v5 = -1055959067;
      }
    }
  }
  while ( v5 != -902648343 );
  v8 = 0;
  printf("%s\n", v7);
  return v9;
}
```

`while(1)`이 여러 개 중첩된다는 점과 `v5`를 큰 정수들과 여러 번 비교한다는 점이 특징이다.

위 예시를 보면 각 basic block마다 다음으로 실행할 basic block을 가리키는 v5값을 바꾸는 것을 알 수 있다. 이 v5값을 따라가면서 프로그램의 흐름을 파악하면 된다.

### 4. Instruction Substitution 결과

<https://github.com/obfuscator-llvm/obfuscator/wiki/Instructions-Substitution>

Instuction Substitution은 add, sub, and, or, xor과 같은 연산을 이상한 값을 포함한 복잡한 연산으로 치환하는 기법이다.

![llvm-obfus-sub](/assets/2015/10/llvm-obfus-sub.jpeg)

Control Flow 자체는 전혀 변하지 않고, 단지 몇몇 arithmetic instruction만 바뀌어 있다. 다른 두 기법에 비하면 리버싱의 난이도를 크게 올리지 않는 것 같다.

### 5. Bogus Control Flow (BCF) 결과

<https://github.com/obfuscator-llvm/obfuscator/wiki/Bogus-Control-Flow>

BCF는 각 basic block 앞에 항상 참인 복잡한 if문을 집어넣고 참일 때는 원래 코드를, 거짓일 때는 원래 코드와 비슷한 가짜 코드를 실행하도록 만드는 난독화 기법이다.

CSAW CTF 2015의 wyvern문제에 BCF기법이 적용되어있었다.

```c
int __cdecl main(int argc, const char **argv)
{
  signed int v2; // edx@4
  int *v3; // rax@13
  int v4; // eax@13
  int v5; // ecx@13
  int v7; // [sp+0h] [bp-20h]@2
  int v8; // [sp+4h] [bp-1Ch]@4
  int *v9; // [sp+8h] [bp-18h]@2
  int *v10; // [sp+10h] [bp-10h]@2
  int *v11; // [sp+18h] [bp-8h]@2

  if ( y >= 10 && (((_BYTE)x - 1) * (_BYTE)x & 1) != 0 )
    goto LABEL_14;
  while ( 1 )
  {
    v7 = 0;
    *(&v7 - 4) = 0;
    v11 = &v7;
    v10 = &v7 - 4;
    v9 = &v7 - 4;
    if ( y < 10 || (((_BYTE)x - 1) * (_BYTE)x & 1) == 0 )
      break;
LABEL_14:
    v7 = 0;
    *(&v7 - 4) = 0;
  }
  while ( *v9 < 10 )
  {
    v2 = *v9;
    v8 = 2;
    if ( v2 % 2 )
    {
      if ( y < 10 || (((_BYTE)x - 1) * (_BYTE)x & 1) == 0 )
      {
LABEL_9:
        *((_BYTE *)v10 + *v9) = *v9 + 65;
        if ( y < 10 || (((_BYTE)x - 1) * (_BYTE)x & 1) == 0 )
          goto LABEL_10;
      }
      *((_BYTE *)v10 + *v9) = *(_BYTE *)v9 + 65;
      goto LABEL_9;
    }
    if ( y >= 10 && (((_BYTE)x - 1) * (_BYTE)x & 1) != 0 )
LABEL_15:
      *((_BYTE *)v10 + *v9) = *(_BYTE *)v9 + 97;
    *((_BYTE *)v10 + *v9) = *v9 + 97;
    if ( y >= 10 && (((_BYTE)x - 1) * (_BYTE)x & 1) != 0 )
      goto LABEL_15;
LABEL_10:
    if ( y >= 10 && (((_BYTE)x - 1) * (_BYTE)x & 1) != 0 )
      goto LABEL_17;
    while ( 1 )
    {
      ++*v9;
      if ( y < 10 || (((_BYTE)x - 1) * (_BYTE)x & 1) == 0 )
        break;
LABEL_17:
      ++*v9;
    }
  }
  v3 = v10;
  *((_BYTE *)v10 + 10) = 0;
  v4 = printf("%s\n", v3, *(_QWORD *)&v7);
  v5 = *v11;
  v7 = v4;
  return v5;
}
```

코드에서 x와 y는 값이 0인 전역변수이다. 따라서 이들이 들어간 if문은 그 결과가 정해져 있다. 필요 이상으로 while과 break가 많고, `y < 10 || (((_BYTE)x - 1) * (_BYTE)x & 1) == 0`와 비슷하게 생긴 조건문이 여럿 나타난다는 것이 BCF의 특징이다.

### 6. (번외) 전부 다 적용하기

![llvm-obfus-all](/assets/2015/10/llvm-obfus-all.png)

그 작은 코드가 엄청나게 불어났다. 원래 프로그램의 로직을 찾아내려면 상당히 귀찮을 것이다.

