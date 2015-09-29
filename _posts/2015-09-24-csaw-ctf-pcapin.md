---
layout: post
title: CSAW CTF 2015 - pcapin
category: writeup
---
pcapin은 네트워크 포렌식 문제다.

> We have extracted a pcap file from a network where attackers were present.
> We know they were using some kind of file transfer protocol on TCP port 7179.
> We're not sure what file or files were transferred and we need you to investigate.
> We do not believe any strong cryptography was employed.
>
> Hint: The file you are looking for is a png.

문제로 주어진 pcap 파일을 열어 보면 깔끔하게 두 컴퓨터 간에 오고 간 TCP 패킷이 보인다. 그런데 TCP 헤더에는 IP와 달리 상위 프로토콜에 대한 정보가 없기 때문에 이들이 어떤 포맷으로 데이터를 주고받았는지 알 수가 없다.

패킷을 직접 분석하기에 앞서 이리저리 검색을 해 보았지만 이 데이터가 무슨 프로토콜로 주고받은 데이터인지 찾을 수 없었다.

## 1. 프로토콜 파악하기

Wireshark에서 `tcp.len > 0`으로 필터링하면 데이터가 있는 패킷만 볼 수 있다. 아래는 TCP가 전달한 데이터를 순서대로 이은 뒤 한 단위로 보이는 부분으로 자른 것이다.

```
- Client -> Server:
0008 0000 0731 f9e9

- Server -> Client:
0044 0000 0732 0001 0000 0000 0025f2a9 8d968a8c849c878dc7898d9fe9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 000028a9 9a988489859cc78d809fe9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 000015c1 868c9d9f80958cd78d989df9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 0005360a 8e8b8c80b69786a68f909b9c9e988595c7838089e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 000015c1 8f95889ec789879ee9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 000221d9 9b9c9a8c849cc7898d9fe9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 00006f00 8e968dd7999a8889879ee9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000
0044 0000 0732 0001 0000 0000 00007a00 8498858e888b8cd78c818cf9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f96000454e44

- Client -> Server:
003a 0000 1502 f9e9 8f95889ec789879ee9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9e9f9
```

문제에서 file transfer protocol 이랬으니까 FTP처럼 첫 부분이 LIST요청, 두 번째 부분이 파일 목록을 담은 응답, 세 번째 부분이 파일 다운로드 요청일 것이라 추정할 수 있다. 실제로 패킷 길이도 그런 것 같이 생겼다. 또, 크게 중요하진 않지만 첫 두 바이트가 패킷의 전체 길이이고, 서버의 응답 맨 끝에는 'END'(454e44)가 붙는다는 점을 알 수 있다.

서버의 파일 목록 응답을 보면 뒤쪽에 e9f9가 엄청 많이 붙어있고, 각 줄의 길이가 모두 같다. e9f9는 아마 길이를 맞추기 위한 null byte일 것이다. 또, 데이터에 적용된 암호화는, 문제에서 어려운 암호는 쓰지 않았다고 했으니 단순한 xor 암호를 의심해볼 수 있다. 각 줄을 0xe9f9로 xor해보면 다음과 같은 문자열을 얻는다. 클라이언트가 요청한 파일 이름도 마찬가지로 e9f9로 xor해보면 `flag.png`임을 알 수 있다.

```
document.pdf
sample.tif
outfile.dat
grey_no_firewall.zip
flag.png
resume.pdf
god.pcapng
malware.exe
```


## 2. 그림 추출하기

답은 서버가 보내준 `flag.png`에 들어있을 것이다. 아래는 pcap파일의 나머지 부분인데, 서버가 보낸 파일의 데이터이다. 너무 길어서 일부 줄였다.

```
00d4 4567 0732001c 0000 0000 d96f1e785d354a35...
00d4 23c6 0732001c 0001 0000 b5182f3f85f716fa...
00d4 9869 0732001c 0002 0000 6b0ba95b9bfe6de4...
00d4 4873 0732001c 0003 0000 39c9046145a11f00...
00d4 dc51 0732001c 0004 0000 ea88870e0ea114d6...
00d4 5cff 0732001c 0005 0000 278c48885f923c02...
00d4 944a 0732001c 0006 0000 394ecaa564e49729...
00d4 58ec 0732001c 0007 0000 55e012dd2ca1037f...
00d4 1f29 0732001c 0008 0000 bf42310b9b69fdc8...
00d4 7ccd 0732001c 0009 0000 d82b879f716927ec...
00d4 58ba 0732001c 000a 0000 cf3a6bfaddaffbef...
00d4 d7ab 0732001c 000b 0000 8ab245f42633f63d...
00d4 41f2 0732001c 000c 0000 1de51ff3531ae640...
00d4 1efb 0732001c 000d 0000 9e5c9571cd18bd61...
00d4 a9e3 0732001c 000e 0000 384f1432cd8de247...
00d4 e146 0732001c 000f 0000 5188897b807c08f3...
00d4 007c 0732001c 0010 0000 3b15d8bd955820b6...
00d4 62c2 0732001c 0011 0000 fb02cdfa59327e63...
00d4 0854 0732001c 0012 0000 a808f6c6bb94abc2...
00d4 27f8 0732001c 0013 0000 48084b50588dbd7f...
00d4 231b 0732001c 0014 0000 f8e06dcbb43c33e2...
00d4 e9e8 0732001c 0015 0000 be3e6e2c869daf8f...
00d4 cde7 0732001c 0016 0000 eb3c37588a72213b...
00d4 438d 0732001c 0017 0000 a50b16cb1ad3501b...
00d4 0f76 0732001c 0018 0000 e9bf33906096eeb7...
00d4 255a 0732001c 0019 0000 00e697c2feb99eb0...
00d4 f92e 0732001c 001a 0000 8e0ec83fcb06fc0a...
00d4 7263 0732001c 001b 0000 a0b58efa2a93939d...(skipped)...4c6c4c6c4c6c4c6c4c6c4c6c454e44
```

중간에 00부터 1b까지 sequence number 처럼 보이는 부분이 있어서 우리가 패킷을 빠트리지 않았다는 것을 증명해준다. 또, 이제까지는 0000이었던 3~4번째 바이트가 줄 마다 다른 데이터로 차 있다.

이 파일이 PNG 파일이니까 PNG magic number인 `89 50 4e 47`로 시작해야 한다. 이에 따라 첫 줄의 xor key는 503f가 된다. 아까와 xor key가 다르다. 가장 마지막 부분을 보자. 4c6c가 많이 보이는 것으로 보아 마지막 부분은 역시 길이를 맞추기 위한 null byte일 테고, xor key는 4c6c일 것이다. 과연 4c6c로 xor해보면 마지막 줄이 PNG 파일의 끝을 알리는 `IEND`로 끝나는 것을 알 수 있다.

문제는 중간 부분인데, 맨 앞줄과 맨 뒷줄의 xor key가 다르기 때문에 나머지 줄들도 각기 다른 xor key를 가질 것이다. xor key에 대한 그 어떤 힌트도 없어서 규칙을 알아내는 데 애를 먹었다.

그러다 우연히 `0xf9e9 + 0x4567 = 0x13f50`이라는 사실을 발견했다. 마찬가지로 `0xf9e9 + 0x7263 = 0x16c4c`였다! 처음 쓰던 xor key인 0xf9e9에다가 3~4번째 바이트를 더하면 그 줄의 xor key가 되는 것이다. 이를 토대로 png 파일을 복구하여 읽으면 답이 된다.

![pcapin](/assets/2015/09/pcapin.png)

