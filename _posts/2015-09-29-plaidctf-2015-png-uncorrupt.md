---
layout: post
title: PlaidCTF 2015 - png uncorrupt
category: writeup
---

> We received this PNG file, but we're a bit concerned the transmission may have not quite been perfect.

### 1. 헤더 보기

```
$ file png_uncorrupt.png
png_uncorrupt.png: data
```

파일 signature에 뭔가 문제가 있다.

```
문제 파일: 89 50 4E 47 0A 1A 0A 00
바른 파일: 89 50 4E 47 0D 0A 1A 0A
```

문제에서 "transmission error"를 언급한 걸 보니 이 뒤에도 `\r\n`(0D 0A)가 `\n`(0A)로 바뀌어있는 듯 하다.

그래서 모든 `\n`을 `\r\n`으로 바꿨더니 그림이 아예 망가졌다. `0A`한 바이트만 보고선 원래 `0A`였는지 `0D 0A`가 잘려서 `0A`가 된 건지 알 수가 없기 때문이었다.

<!--more-->

### 2. 파일 구조 분석

010 Editor 로 열어보았다. 첫 번째 IDAT 청크에 CRC 오류가 있었다. 자세히 보니 파일에는 길이가 0x2000이라고 되어 있었는데, 다음 IDAT 청크까지의 길이를 재어 보니 실제로는 0x1FFFF였다. 그렇다면, 데이터 안에 있는 `0A`중 하나 앞에 `0D`를 집어넣으면 CRC가 맞게 되리라 예상할 수 있다.

이런 식으로 분석을 계속했더니 1~3바이트씩 데이터가 부족한 IDAT 청크가 총 10개 발견되었다.

### 3. 파일 고치기

각 청크마다, 길이가 부족한 만큼 데이터 안에서 `0A`를 찾아서 앞에 `0D`를 붙이고 CRC를 계산해서 파일에 적힌 값과 비교해 본다.

```py
import struct
import zlib
import re
import itertools

def __unpack(s):
    return struct.unpack(">I", s)[0]

def __pack(i):
    return struct.pack(">I", i)

def pngcrc(data):
    return zlib.crc32(data) & 0xFFFFFFFF

def read_chunk(f):
    length = __unpack(f.read(4))
    name = f.read(4)
    body = f.read(length)
    stored_crc = __unpack(f.read(4))
    actual_crc = pngcrc(name + body)
    print "%06x %s %08x %08x" % (length, name, actual_crc, stored_crc)
    return __pack(length) + name + body + __pack(stored_crc)

def read_actual_idat(data):
    try:
        endp = data.index("IDAT", 8) - 4
    except ValueError:
        endp = data.index("IEND", 8) - 4
    length = __unpack(data[:4])
    name = data[4:8]
    body = data[8:endp-4]
    crc = __unpack(data[endp-4:endp])
    print "%06x %06x %s %08x" % (length, len(body), name, crc)
    return length, name, body, crc

def comb(n, r):
    def __fact(n):
        f = 1
        while n > 0:
            f *= n
            n -= 1
        return f
    return __fact(n) / __fact(n-r) / __fact(r)


def brute_crc(count, name, body, crc):
    positions = [m.start() for m in re.finditer("\x0a", body)]
    candidates = itertools.combinations(positions, count)
    print "Fixing %d points, %d possibilities" % (count, comb(len(positions), count))
    for points in candidates:
        points = [0] + list(points) + [len(body)]
        fixed = ""
        for i in range(count+1):
            start = points[i]
            end = points[i+1]
            fixed += body[start:end] + "\x0d"
        fixed = fixed[:-1]
        if pngcrc(name + fixed) == crc:
            print "Found", points
            return fixed
    raise ValueError("Cannot fix error")

def fix_chunk(data):
    length, name, body, crc = read_actual_idat(data)
    actual_length = len(body)
    fixed_body = brute_crc(length - actual_length, name, body, crc)
    fixed_chunk = __pack(length) + name + fixed_body + __pack(crc)
    return fixed_chunk, actual_length + 12

def main():
    f = open("corrupt.png")
    g = open("fixed.png", "w")

    magic = f.read(8)
    g.write(magic)
    # Skip metadata chunks
    for i in range(4):
        chunk = read_chunk(f)
        g.write(chunk)
    print

    data = f.read()
    f.close()
    while True:
        chunk, pos = fix_chunk(data)
        data = data[pos:]
        g.write(chunk)
        g.flush()
    g.close()

main()
```

약 3분만에 정답을 얻었다.

![corrupt.png](/assets/2015/09/corrupt.png)
고치기 전.

![fixed.png](/assets/2015/09/fixed.png)
고친 후.

```
flag{have_a_wonderful_starcrafts}
```
