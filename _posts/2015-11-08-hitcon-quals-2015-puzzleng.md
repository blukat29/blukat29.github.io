---
layout: post
title: HITCON Quals 2015 - puzzleng
category: writeup
---

> Next Generation of Puzzle!

puzzleng은 파일을 암호화해주는 프로그램인 `encrypt`와 암호화된 파일인 `flag.puzzle`두 파일로 구성된 forensic 문제이다.

### 1. encrypt 분석

encrypt는 간단한 프로그램이다. 암호화 과정은 다음과 같다.

- 주어진 비밀번호를 SHA1 해시하여 얻은 20바이트를 암호화 키로 사용한다.
- 대상 파일을 같은 크기의 20조각으로 나누어 각 조각을 암호화 키의 한 바이트로 xor한다.

### 2. 파일 헤더 복구

암호화 키에 대한 정보가 하나도 없으므로 직접 모든 경우를 대입해 봐야 한다. 그러나 20바이트를 전부 시도할 수는 없어서 파일 헤더가 있을 것으로 예상되는 첫 번째 블록만 xor해보았다.

```py
from hexdump import hexdump

f = open("flag.puzzle")
raw = f.read()
f.close()

raw = map(ord, list(raw))
L = len(raw)
B = (L + 19) // 20
k = [0]*20

def decrypt():
    for i in range(20):
        start = i * B
        end = min((i+1) * B, L)
        for j in range(start, end):
            raw[j] ^= k[i]

def dump_block(i):
    start = i * B
    end = min((i+1) * B, L)
    block = raw[start:end]
    block = ''.join(map(chr, block))
    hexdump(block)

n = 0
for i in range(256):
    print "="*40, i
    k[n] = i
    decrypt()
    dump_block(n)
    decrypt()
```

그 결과 키의 첫 번째 바이트가 101일 때 PNG 헤더가 나오는 것을 확인했다.

```
======================================== 101
00000000: 89 50 4e 47 0d 0a 1a 0a  00 00 00 0d 49 48 44 52  .PNG........IHDR
00000010: 00 00 03 90 00 00 03 90  01 03 00 00 00 75 82 0c  .............u..
00000020: 67 00 00 00 06 50 4c 54  45 8f 77 b5 8f 77 b4 6d  g....PLTE.w..w.m
00000030: c4 59 ac 00 00 00 02 74  52                       .Y.....tR
```

이제 파일이 PNG임을 알았으니 두 번째 블록도 같은 방법으로 복호화할 수 있다. `IDAT`와 `IEND`를 찾은 결과 키의 두 번째 바이트는 48이고, 마지막 바이트는 27임을 알아냈다.

```
======================================== 48
00000000: 4e 53 ff ff c8 b5 df c7  00 00 00 09 70 48 59 73  NS..........pHYs
00000010: 00 00 0b 12 00 00 0b 12  01 d2 dd 7e fc 00 00 04  ...........~....
00000020: 01 49 44 41 54 78 9c ed  cf 41 8a e4 30 0c 05 d0  .IDATx...A..0...
00000030: dc ff d2 35 8b c6 48 5f  76                       ...5..H_v
```

```
======================================== 27
00000000: 6b c9 bf 5b 48 24 12 89  44 22 91 48 24 12 89 44  k..[H$..D".H$..D
00000010: 22 91 48 24 12 89 44 22  91 48 24 12 79 5c ff 00  ".H$..D".H$.y\..
00000020: c3 f9 b0 34 d9 bf 3b 6a  00 00 00 00 49 45 4e 44  ...4..;j....IEND
00000030: ae 42 60 82                                       .B`.
```

파일 헤더를 분석해 보면 몇 가지를 알아낼 수 있다.

- PLTE 섹션에 두 개의 색이 정의되어 있고, 이 이미지는 각 픽셀을 1bit로만 표현한다. 이 palette 색 두 개가 매우 비슷하므로 흰색/검정색으로 바꿔주어야 한다.
- 그림 사이즈가 912x912이다.
- IDAT에 들어있는 데이터는 deflate 알고리즘으로 압축되어있다.

### 3. gzip 헤더 복구

데이터 부분의 gzip 헤더가 일부 남아있어서, 압축을 일단 풀고 육안으로 그림을 확인해 가는 방법을 쓰려고 했다. 그러나 압축이 풀리지 않았다. gzip 헤더가 손상된 것이다. 헤더의 나머지 부분을 복구하기 위해 키의 세 번째 바이트를 맞춰보았다.

맞춰볼 때 데이터 부분 전체를 `zlib.decompress`로 풀었더니 모든 경우에서 exception이 발생했다. 따라서 복구된 앞 부분과 세 번째 부분만을 사용해야 했고, 이것도 `zlib.decompressobj().decompress`를 써서 해야 맞는 키를 찾을 수 있었다. 세 번째 바이트는 86이다.

```py
def get_block(n):
    start = n * B
    end = min((n+1) * B, L)
    block = raw[start:end]
    block = ''.join(map(chr, block))
    return block

k[0] = 101
k[1] = 48
k[19] = 27
decrypt()
zlib_head = ''.join(map(chr,raw[0x5e:2*B]))

for i in range(256):
    k[2] = i
    decrypt()
    data = zlib_head + get_block(2)
    print i
    try:
        zlib.decompressobj().decompress(data)
        print "=============OK"
    except:
        pass
    decrypt()
```

### 4. 데이터 복구

그 다음부터는 데이터가 어떤 값이던지 간에 압축이 잘 풀렸다. 여기부터는 PLTE를 흰색과 검정색으로 바꿔 눈으로 보기 쉽게 만들고, 키의 한 바이트를 바꿔가며 눈으로 확인했다.

```py
k[0] = 101
k[1] = 48
k[19] = 27
k[2] = 86
decrypt()
# Fix PLTE to be black/white
raw[0x29] = 0x00
raw[0x2a] = 0x00
raw[0x2b] = 0x00
raw[0x2c] = 0xff
raw[0x2d] = 0xff
raw[0x2e] = 0xff
# Fix CRC32 or PLTE
print hex(zlib.crc32("PLTE\x00\x00\x00\xff\xff\xff") & 0xffffffff) # a5d99fdd
raw[0x2f] = 0xa5
raw[0x30] = 0xd9
raw[0x31] = 0x9f
raw[0x32] = 0xdd
decrypt()
```

```py
n = 3
for i in range(256):
    k[3] = i
    decrypt()
    f = open("%03d.png" % i, "w")
    f.write(''.join(map(chr, raw)))
    f.close()
    decrypt()
```

키의 네 번째 바이트가 195일 때 그림에 QR코드의 윗부분이 나타났다.

![195](/assets/2015/11/puzzleng_195.png)

이런 식으로 나머지 15바이트도 맞추면 아래와 같은 QR코드을 얻을 수 있다. 키는 `[101, 48, 86, 195, 120, 255, 75, 191, 247, 71, 55, 227, 111, 83, 38, 76, 37, 244, 209, 27]` 이다.


![final](/assets/2015/11/puzzleng_qr.png)



`hitcon{qrencode -s 16 -o flag.png -l H --foreground 8F77B5 --background 8F77B4}`

