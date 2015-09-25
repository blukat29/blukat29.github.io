---
layout: post
title: CSAW CTF 2015 - HackingTime
category: writeup
---
HackingTime은 NES 리버싱 문제이다. NES파일은 이번 대회에서 처음 다뤄보는지라 조금 헤맸다. NES, 또는 iNES ROM은 [닌텐도 패미컴](https://ko.wikipedia.org/wiki/%ED%8C%A8%EB%B0%80%EB%A6%AC_%EC%BB%B4%ED%93%A8%ED%84%B0)용 프로그램이다.

## 1. Environment Setup
NES 에뮬레이터는 종류가 많은데, 간단히 실행만 하려면 VirtuaNES로도 충분하고, 디버깅을 하려면 Nintendulator를 사용해야 한다. IDA에서 NES 파일이 열리지 않는 경우, [IDA NES loader](https://github.com/patois/nesldr)를 다운받아 설치해야 한다. 설치는 `nes.ldw`파일을 `<IDA install directory>\loaders`에 넣기만 하면 끝이다.

## 2. NES 리버싱

NES는 Motorola 6502를 개조한 8비트 프로세서 기반이다. 주로 사용하는 레지스터는 A,X,Y 세 개이고 각각 8비트씩이다. 몇 가지 어셈블리를 소개하고 넘어가겠다.

{% highlight text %}
LDA #$12      # Load constant 0x12 to A
STA 0x39      # Store A to memory address 0x39
TXA           # Transfer X to A
JSR sub_8233  # Call function at 0x8233
LDA 3, Y      # Load byte at (Y+3) to A
CPY #24       # Compare Y against const 24
BNE lab_8102  # Branch if not equal
{% endhighlight %}

아래 사이트가 아주 유용했다.

- 6502 어셈블리 일람 [http://www.6502.org/tutorials/6502opcodes.html](http://www.6502.org/tutorials/6502opcodes.html)
- NES 어셈블리 튜토리얼 [http://patater.com/nes-asm-tutorials/](http://patater.com/nes-asm-tutorials/)

## 3. 실행 시켜보기

화면 상에 A키를 누르라고 나오면 키보드 X키를 누르면 된다. 게임을 진행하다 보면 아래와 같이 비밀번호를 요구하는 스테이지가 나온다. 올바른 비밀번호가 문제의 답일 것이다.

![HackingTime](/assets/2015/09/hackingtime.png)

## 4. 비밀번호 루틴 찾기

이제 저 비밀번호를 묻는 부분을 찾아야 한다. 프로그램이 상당히 방대했고 어셈블리가 낯설었기 때문에 _RESET부터 top-down으로 가는 방법은 어렵다고 판단했다. 그래서 화면에 출력되는 문자열을 기준으로 찾기로 했다.

화면에 나온 `"LOCKDOWN"`은 0x958E에 있다. 그러나 레지스터가 8비트 밖에 표현하지 못하므로 0x958E가 코드 상에 그대로 나타나지는 않을 것이다. 그래서 0x8E, 즉 `#$8E`를 검색했다. 그렇게 해서 비밀번호 루틴인 sub_805A를 찾았다.

{% highlight text %}
ROM:8086      LDA     #$8E
ROM:8088      STA     byte_39
ROM:808A      LDA     #$95
ROM:808C      STA     byte_3A
ROM:808E      LDX     #$A
ROM:8090      LDY     #3
ROM:8092      JSR     print    ; 0x958E "LOCKDOWN" at 10,3
ROM:8095      JSR     wait_key
ROM:8098      LDA     #$99
ROM:809A      STA     byte_39
ROM:809C      LDA     #$95
ROM:809E      STA     byte_3A
ROM:80A0      LDX     #6
ROM:80A2      LDY     #5
ROM:80A4      JSR     print    ; 0x9599 "ENTER THE PASSWORD" at 6,5
{% endhighlight %}

코드를 보면 문자열의 주소를 메모리 0x39:0x3A에 넣고 레지스터 X, Y에는 문자열을 출력할 좌표값을 넣은 뒤 print(sub_8422)를 호출하면 문자열이 출력되는 것 같다.

## 5. 비밀번호 루틴 분석

![HackingTime2](/assets/2015/09/hackingtime2.png)

Graph overview를 보니 전형적인 switch-case 구조다. flow가 갈라지기 시작하는 loc_80F2에서 부르는 sub_834D를 보면 Joypad_1이라는 메모리 영역에 접근하는 것을 볼 수 있다. 즉, 화살표 키를 하나 입력받아서 그에 따른 작업을 수행하는 것이다.

![HackingTime3](/assets/2015/09/hackingtime3.png)

오른쪽 부분을 보면 byte_3D값을 0x17(비밀번호의 길이가 24이다)이나 0과 비교하고 1씩 증가하거나 감소하는 것을 볼 수 있다. 그리고 바로 다음에는 byte_3D의 값을 X에 옮긴 뒤 (X+3,8)과 (X+3,10)위치에 문자열을 출력한다. 따라서 이 부분은 오른쪽, 왼쪽 키가 눌렸을 때 화살표 표시를 이동시켜주는 부분이다.

또한 왼쪽 부분에는 'A','Z','0','9'와 같은 상수가 등장하므로 위, 아래 키를 눌렀을 때 A-Z,0-9를 순환시켜주는 부분이라고 추측할 수 있다. 그리고 선택된 문자열은 메모리 상의 (*byte_3D+5) 위치에 저장된다는 것도 알 수 있다. 디버거를 통해 보면 이 점이 확실해진다. 비밀번호는 메모리의 0x5부터 24바이트 만큼 저장된다.

이제 자동적으로 가운데 부분이 A키(키보드 X키)를 눌렀을 때 비밀번호를 확인해서 "ACCESS DENIED"를 띄워주는 부분이라고 추측할 수 있다.

실제 비밀번호를 체크하는 부분은 0x82F1이다. 이 함수는 0x955E와 0x9576에 있는 각 24바이트짜리 테이블을 사용하고 ROL, ROR, XOR등으로 이루어져 있다. 아래는 키젠 스크립트이다.

{% highlight python %}
u = """
$70, $30, $53, $A1, $D3, $70, $3F, $64, $B3, $16
$E4, 4, $5F, $3A, $EE, $42, $B1, $A1, $37, $15, $6E
$88, $2A, $AB
""".replace('$','').replace(',','').split()
u = map(lambda x: int(x,16), u)

v = """
$20, $AC, $7A, $25, $D7, $9C, $C2, $1D, $58, $D0
$13, $25, $96, $6A, $DC, $7E, $2E, $B4, $B4, $10
$CB, $1D, $C2, $66
""".replace('$','').replace(',','').split()
v = map(lambda x: int(x,16), v)

ROL = lambda val, r_bits: \
    (val << r_bits%8) & (2**8-1) | \
    ((val & (2**8-1)) >> (8-(r_bits%8)))

ROR = lambda val, r_bits: \
    ((val & (2**8-1)) >> r_bits%8) | \
    (val << (8-(r_bits%8)) & (2**8-1))

s = 0
x = [0]*24
rng = map(ord, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

for i in range(24):
    for c in rng:
        t = s
        t = ROR(t,2)
        t = (t + ROL(c,3)) & 0xFF
        t = (t ^ u[i]) & 0xFF
        if v[i] ^ ROL(t,4) == 0:
            s = t
            x[i] = c
            break
print ''.join(map(chr, x))
{% endhighlight %}

답은 NOHACK4UXWRATHOFKFUHRERX 이다.

