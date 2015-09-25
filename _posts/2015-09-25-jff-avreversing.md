---
layout: post
title: JFF 3 - AVReversing
category: writeup
---

AVReversing은 LeaveRet에서 주관한 제 3회 Just For Fun CTF 2015에 나온 AVR 리버싱 문제다.

AVR 리버싱에 대한 전반적인 내용은 아래 글에 나와 있다.

- [AVR Architecture](/2015/09/avr-memory-and-registers/)
- [AVR Reversing Tips](/2015/09/avr-reversing/)
- [Debugging AVR](/2015/09/debugging-avr/)

### 1. Reverse

프로그램 안에 printf와 scanf가 포함되어있기 때문에 printf 안으로 들어가 헤메지 말고 함수 argument를 보고 무슨 함수인지를 알아맞히며 넘어가야 한다.

strcpy, memcpy, memcmp 등은 함수가 작아서 코드를 보면 알 수 있다.

프로그램의 대략적인 구조는 다음과 같다. 코드에서 r25:r24는 w24, r23:r22는 w22... 등으로 표시했다.

{% highlight c %}
void main_FE() {
    // (setup some global variables)
    // (initialize UART console)
    main2_11E();
}

void main2_11E() {
  SP[1:2] = 0x100;            // 0x100: "input:"
  printf_194();
  main3_127();
}

void main3_127() {
  SP[1:2] = 0x107;            // 0x107: "%s"
  SP[3:4] = SP+1;
  scanf_1DD();
  r24 = check_8A(SP+1);
  if (r24 == 0)
    puts_1A6(0x116);          // 0x116: "wrong! :("
  else
    printf_194(0x10A, SP+1);  // 0x10A: "flag is %s\n"
}

void check_8A(char* input) {  // input given through w24, stored at w14
  char table[0x1A];   // SP+1
  char buf[0x1B];     // SP+0x1B, w16

  memcpy(table, 0x13C, 0x1A);
  // 0x13C:
  // 27 F6 76 D6 05 13 A4 85  D3 D7 B6 F7 96 25 74 A3
  // F4 36 75 54 15 76 56 E7  67 02

  if (strlen(input) + 1 != 0x1B) return 0;
  strcpy_18D(buf, input);

  char* w26 = buf;
  char* w20 = buf;
  int w18 = 0;
  while (1) {
    w30 = strlen(input);
    if (w18 >= w30) break;
    *w20 ^= w18;
    w20++;
    w18++;
  }

  int w24 = 0;
  while (1) {
    w20 = strlen(input);
    if (w24 >= w20) break;
    r18 = *w26;
    *w26++ = swap(r18);    // swap nibbles
    w24 ++;
  }

  r24 = memcmp(table, buf, w20);
}
{% endhighlight %}

### 2. keygen

{% highlight py %}
target = """
27 F6 76 D6 05 13 A4 85  D3 D7 B6 F7 96 25 74 A3
F4 36 75 54 15 76 56 E7  67 02
""".replace(' ','').replace('\n','').decode('hex')
target = map(ord, target)

def swap(x):
    hi = (x & 0x0F) << 4;
    lo = (x & 0xF0) >> 4;
    return (hi | lo)

a = target[:]
for i in range(0x1A):
    a[i] = swap(a[i]) ^ i

print ''.join(map(chr, a))
{% endhighlight %}

정답은 `rnenT4L_5tate_I5_rEVErsin9` 이다.

