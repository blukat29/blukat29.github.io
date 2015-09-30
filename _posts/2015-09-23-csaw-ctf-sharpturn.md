---
layout: post
title: CSAW CTF 2015 - Sharpturn
category: writeup
---

> I think my SATA controller is dying.

Sharpturn은 400점짜리 포렌식 문제다. `sharpturn.tar.xz`파일이 주어졌는데, 이런 파일이 들어있었다.

```
HEAD  branches/  config  description  hooks/  info/  objects/  refs/
```

Git 저장소의 `.git/` 디렉토리임을 대번에 알 수 있었다.

## 1. 파일 복구하기

커밋 로그로부터 원본 파일을 복구하는 건 전혀 어렵지 않다. 여러 가지 방법이 있는데, 나는 local repository를 clone하는 방법을 써서 `Makefile`과 `sharp.cpp`, 두 파일을 얻었다. `sharp.cpp`는 이렇게 생겼다.

```cpp
#include <iostream>
#include <string>
#include <algorithm>

#include <stdint.h>
#include <stdio.h>
#include <openssl/sha.h>

using namespace std;

std::string calculate_flag(
                std::string &part1,
                int64_t part2,
                std::string &part4,
                uint64_t factor1,
                uint64_t factor2)
{

        std::transform(part1.begin(), part1.end(), part1.begin(), ::tolower);
        std::transform(part4.begin(), part4.end(), part4.begin(), ::tolower);

        SHA_CTX ctx;
        SHA1_Init(&ctx);

        unsigned int mod = factor1 % factor2;
        for (unsigned int i = 0; i < mod; i+=2)
        {
                SHA1_Update(&ctx,
                                reinterpret_cast<const unsigned char *>(part1.c_str()),
                                part1.size());
        }


        while (part2-- > 0)
        {
                SHA1_Update(&ctx,
                                reinterpret_cast<const unsigned char *>(part4.c_str()),
                                part1.size());
        }

        unsigned char *hash = new unsigned char[SHA_DIGEST_LENGTH];
        SHA1_Final(hash, &ctx);

        std::string rv;
        for (unsigned int i = 0; i < SHA_DIGEST_LENGTH; i++)
        {
                char *buf;
                asprintf(&buf, "%02x", hash[i]);
                rv += buf;
                free(buf);
        }

        return rv;
}

int main(int argc, char **argv)
{
        (void)argc; (void)argv; //unused

        std::string part1;
        cout << "Part1: Enter flag:" << endl;
        cin >> part1;

        int64_t part2;
        cout << "Part2: Input 51337:" << endl;
        cin >> part2;

        std::string part3;
        cout << "Part3: Watch this: https://www.youtube.com/watch?v=PBwAxmrE194" << endl;
        cin >> part3;

        std::string part4;
        cout << "Part4: C.R.E.A.M. Get da _____: " << endl;
        cin >> part4;

        uint64_t first, second;
        cout << "Part5: Input the two prime factors of the number 270031727027." << endl;
        cin >> first;
        cin >> second;

        uint64_t factor1, factor2;
        if (first < second)
        {
                factor1 = first;
                factor2 = second;
        }
        else
        {
                factor1 = second;
                factor2 = first;
        }

        std::string flag = calculate_flag(part1, part2, part4, factor1, factor2);
        cout << "flag{";
        cout << &lag;
        cout << "}" << endl;

        return 0;
}
```

일단 코드에 오타가 있어서 조금 고쳐서 컴파일 해야 한다. 게다가 270031727027의 소인수가 네 개라서 어느 두 소수를 말하는 건지 알 수도 없었다. 그래서 프로그램이 하라는 대로 입력을 넣고, 마지막 part5에 소인수 네 개중 두 개를 골라 넣어도 그렇게 나온 flag는 정답이 아니다.

## 2. 진짜 파일 복구하기

문제에서 SATA 컨트롤러에 문제가 있다고 하니 파일이 손상되었을 가능성을 생각해 보아야 한다. 관련 키워드로 인터넷을 뒤져보니 `git fsck`를 돌려보란다.

```text
$ git fsck
Checking object directories: 100% (256/256), done.
error: sha1 mismatch 354ebf392533dce06174f9c8c093036c138935f3
error: 354ebf392533dce06174f9c8c093036c138935f3: object corrupt or missing
error: sha1 mismatch d961f81a588fcfd5e57bbea7e17ddae8a5e61333
error: d961f81a588fcfd5e57bbea7e17ddae8a5e61333: object corrupt or missing
error: sha1 mismatch f8d0839dd728cb9a723e32058dcc386070d5e3b5
error: f8d0839dd728cb9a723e32058dcc386070d5e3b5: object corrupt or missing
missing blob 354ebf392533dce06174f9c8c093036c138935f3
missing blob f8d0839dd728cb9a723e32058dcc386070d5e3b5
missing blob d961f81a588fcfd5e57bbea7e17ddae8a5e61333
```

문제로 주어진 저장소에는 `sharp.cpp`가 총 네 가지 버전이 있는데, sha1 에러가 난 세 object는 각각 `sharp.cpp`의 두번째, 세번째, 네번째 버전이다.
두 번째 버전(`354ebf392533dce06174f9c8c093036c138935f3`)은 다음과 같다.

```cpp
#include <iostream>
#include <string>
#include <algorithm>

using namespace std;

int main(int argc, char **argv)
{
        (void)argc; (void)argv; //unused

        std::string part1;
        cout << "Part1: Enter flag:" << endl;
        cin >> part1;

        int64_t part2;
        cout << "Part2: Input 51337:" << endl;
        cin >> part2;

        std::string part3;
        cout << "Part3: Watch this: https://www.youtube.com/watch?v=PBwAxmrE194" << endl;
        cin >> part3;

        std::string part4;
        cout << "Part4: C.R.E.A.M. Get da _____: " << endl;
        cin >> part4;

        return 0;
}
```

이 파일에 문제가 있어서 sha1 해시가 다르다는 건데, 틀릴 만한 부분은 숫자밖에 없다고 가정하고 sha1을 맞추려고 해보았다.
그 결과 '51337'을 '31337'로 고치면 sha1해시가 맞게 된다는 것을 알아냈다.

세 번째 버전(`d961f81a588fcfd5e57bbea7e17ddae8a5e61333`)은 두 번째 버전에 다음 부분이 추가된 버전이다.

```text
+     uint64_t first, second;
+     cout << "Part5: Input the two prime factors of the number 270031727027." << endl;
+     cin >> first;
+     cin >> second;
+
+     uint64_t factor1, factor2;
+     if (first < second)
+     {
+             factor1 = first;
+             factor2 = second;
+     }
+     else
+     {
+             factor1 = second;
+             factor2 = first;
+     }

```

일단, 내용을 바꿔가며 sha1을 계산하기 전에 이때 파일의 앞부분에 있는 51337을 31337로 바꿔야 한다. 여기서 틀릴 만한 부분은 저 문제의 270031727027일 것이다. 그러나 모든 숫자를 테스트 하기엔 너무 숫자가 크다. 그래서 숫자 하나만 바뀌었다고 가정하고 숫자를 바꿔가며 sha1을 계산해보았다.
그 결과 저 숫자를 272031727027로 바꿔야 한다는 결론이 나왔다. 272031727027은 31357 * 8675311이기 때문에 맞는 것 같았다.

이렇게 두 숫자를 고치고 컴파일 한 뒤 다음과 같은 입력을 주면 올바른 flag를 출력한다.

```
$ ./sharp
flag
31337
asdf
money
31357 8675311
flag{3b532e0a187006879d262141e16fa5f05f2e6752}
```

아래는 sha1을 맞출 때 사용한 스크립트이다.

```py
#!/usr/bin/env python
import itertools
import hashlib
import sys
import zlib

def compute_hash(s):
    try:
        h = hashlib.sha1(s).hexdigest()
        return h
    except:
        return None

def brute_number(s):
    for i in range(100000):
        t = s.replace("51337",str(i))
        h = compute_hash(t)
        if h == goal:
            print i, h
            print "Found!"
            return

def brute_number2(s):
    s = s.replace('51337','31337')
    n = list('270031727027')
    for i in range(12):
        for j in range(10):
            m = n[:]
            m[i] = str(j)
            t = s.replace('270031727027',''.join(m))
            h = compute_hash(t)
            if h == goal:
                print ''.join(m), h
                print "Found!"
                return

if __name__ == '__main__':
    f = open("sharpturn/objects/35/4ebf392533dce06174f9c8c093036c138935f3")
    goal = "354ebf392533dce06174f9c8c093036c138935f3"
    s = zlib.decompress(f.read())
    f.close()
    brute_number(s)

    f = open("sharpturn/objects/d9/61f81a588fcfd5e57bbea7e17ddae8a5e61333")
    goal = "d961f81a588fcfd5e57bbea7e17ddae8a5e61333"
    s = zlib.decompress(f.read())
    f.close()
    brute_number2(s)
```

