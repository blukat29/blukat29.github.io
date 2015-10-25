---
layout: post
title: LD_PRELOAD hooking
category: reversing
---

<https://rafalcieslak.wordpress.com/2013/04/02/dynamic-linker-tricks-using-ld_preload-to-cheat-inject-features-and-investigate-programs/>

```c
/* target.c */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(){
  srand(time(NULL));
  int i = 10;
  while(i--) printf("%d\n",rand()%100);
  return 0;
}
```

```c
/* hook.c */
int rand()
{
  return 42;
}
```

이렇게 두 파일을 작성한다.

```
gcc target.c -o target
./target
```

이걸 실행하면 0~99 사이의 랜덤한 숫자가 열 개 출력된다.

```
gcc -shared -PIC hook.c -o hook.so
env LD_PRELOAD=$PWD/hook.so ./target
```

이렇게 `hook.so`를 만들고 `LD_PRELOAD`를 설정한 뒤 실행하면 42가 열 개 출력된다. 함수 이름만 맞춰주면 모든 dynamically linked call을 후킹할 수 있다.

