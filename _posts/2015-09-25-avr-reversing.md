---
layout: post
title: AVR Reversing
category: AVR
---

AVR instruction set은 공식 문서에 잘 나와 있으므로 아래를 참고하면 된다. 각각의 인스트럭션은 이 글에서 설명하지 않겠다.

<http://www.atmel.com/webdoc/avrassembler/avrassembler.wb_instruction_list.html>
<http://www.atmel.com/Images/doc1022.pdf>

이 글은 C언어로 작성된 AVR프로그램에 등장하는 패턴을 적어놓은 것이다.

### 1. 프로그램 구조

프로그램은 __RESET이라는 지점에서 시작한다. 보통 프로그램의 제일 처음 (0x0000)에 보면 `jmp __RESET`인스트럭션이 있다. __RESET에서는 SP값을 세팅하고 SRAM에 .data섹션의 내용을 load한 뒤 main을 호출한다.

main부터는 일반적인 C함수와 마찬가지로 callee-save인 레지스터를 push하고, SP를 내리고 지역변수를 레지스터와 스택에 저장한다.

AVR 하드웨어에는 프로그램을 하나만 올리기 때문에 모든 라이브러리 함수가 static하게 compile되어있다. 따라서 AVR 프로그램을 리버싱 할 땐 printf나 strcmp따위의 라이브러리 함수를 찾아내는 것이 중요하다.

### 2. Addresses

AVR은 8비트 프로세서라 레지스터가 8비트씩인데 주소는 16비트까지 지원한다. 그래서 함수의 parameter 하나는 두 개의 레지스터로 이뤄져 있다. 그래서 16비트  상수 address (printf의 format string과 같은)를 전달해야 하면 두 번의 LDI 인스트럭션이나 ADD, ADC 인스트럭션을 이용해 두 번에 걸쳐 상수를 세팅하게 된다.

{% highlight text %}
ser     r28
ldi     r29, 0x10   ; Y = 0x10ff
out     SPH, r29
out     SPL, r28    ; SP = Y
{% endhighlight %}

### 3. Function Calls

AVR에서는 일반적으로 argument를 레지스터를 통해 넘겨준다. argument는 각각 레지스터 2개씩 차지하며 순서대로 r25:r24, r23:r22, r21:r20, ... 에 담아서 넘겨준다. Return value도 같은 위치에 담기는데, return value는 보통 한 개이므로 r25:r24에 담아서 돌려준다.

{% highlight text %}
ldi     r20, 0xA
ldi     r21, 0      ; arg3 = 0x000A
movw    r22, r28
subi    r22, -1
sbci    r23, -2     ; arg2 = SP + 0x101
movw    r24, r28
subi    r24, -0xB
sbci    r25, -2     ; arg1 = SP + 0x10B
rcall   memcmp_8F5  ; memcmp(src, dest, len)
{% endhighlight %}

그런데 argument를 x86처럼 스택에 넘겨줄 때도 있다.

{% highlight text %}
ldi     r24, 7
ldi     r25, 1      ; r25:r24 = 0x107
in      r30, SPL
in      r31, SPH    ; Z = SP
std     Z+2, r25
std     Z+1, r24    ; Z[1:2] = 0x107
movw    r16, r28
subi    r16, -1
sbci    r17, -1     ; r17:r16 = SP + 0x1
std     Z+4, r17
std     Z+3, r16    ; Z[3:4] = SP + 0x1
call    sub_1DD     ; scanf(format, ...)
{% endhighlight %}

참고로 위 코드의 경우 .data:0x107에 "%d"가 있기 때문에 sub_1DD가 scanf라는 것을 알 수 있다.

### 4. UART I/O

UART는 Serial port(한 번에 1비트 밖에 보내지 못한다)를 통해 바이트들을 보내는 방식이며 장치이다. C프로그램은 UART로 터미널 입출력을 한다.

UART 통신은 AVR에서 Extended I/O를 통해 이뤄진다. 그 주소는 보통 0x9B가 control & status register (UCSR0A), 0x9C가 data register (UDR0)이다.

UART에 바이트를 읽거나 쓰려면 UCSR에 특정 비트가 켜질 때까지 기다린 뒤, 데이터를 일거나 써야 한다. 그래서 AVR 프로그램에 포함된 putchar(), getchar()함수는 다음과 같이 생겼다.

![UART](/assets/2015/09/avr_uart.jpeg)

### 5. Arithmetics

AVR에서 16비트 수를 다룰 때는 두 개 이상의 인스트럭션이 필요하다.

{% highlight text %}
add     r8, r20
adc     r9, r21    ; r8:r9 += r21:r20
subi    r24, -0xB
sbci    r25, -0x1  ; r25:r24 += 0xB (carry가 있다는 것에 주의할 것)
cp      r26, r22
cpc     r27, r23   ; compare r27:r26 and r23:r22
{% endhighlight %}

AVR에는 곱셉, 나눗셈과 나머지 연산이 없어서 그 연산이 shift, add, sub 등을 조합해서 구현되어 있다. 그래서 알아보기 어려울 수 있다. 아래 문서에 곱셈과 나눗셈 알고리즘이 그림으로 설명되어 있다.

Multiply and Divide Routines - <http://www.atmel.com/Images/doc0936.pdf>


