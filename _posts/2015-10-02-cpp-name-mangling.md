---
layout: post
title: C++ Name Mangling
category: reversing
---

C++은 함수 오버라이딩, 함수 오버로딩, 연산자 오버로딩, 템플릿 등 복잡한 기능이 있는 언어이다. 그래서 C++의 함수나 타입은 `std::allocator<char>::allocator()`처럼 특수문자가 들어간 복잡한 이름을 가질 수가 있다.

그래서 컴파일러는 이런 이름들을 `_ZNSaIcEC1Ev`와 같은 형식으로 이름을 변환해서 사용하는데, 이를 name mangling이라고 부른다.

Name mangling 형식은 컴파일러마다 다르다. 컴파일러에 따라 어떻게 다른 지 궁금하다면 [여기](https://en.wikipedia.org/wiki/Name_mangling#How_different_compilers_mangle_the_same_functions)를 참고하면 된다.

GCC로 mangling된 이름을 원래대로 돌리고 싶다면 `c++filt`라는 툴을 쓰면 된다.

```
$ c++filt -n _ZNSaIcEC1Ev
std::allocator<char>::allocator()
```

ltrace상에 나오는 mangling된 이름을 원래대로 표시하고 싶다면 `-C`옵션을 쓰면 된다.

```
$ ltrace ./knockedupd
__libc_start_main(0x404497, 1, 0x7fff40725b88, 0x406ba0 <unfinished ...>
_ZNSt8ios_base4InitC1Ev(0x6093f8, 0xffff, 0x7fff40725b98, 3)                                                                  = 0
__cxa_atexit(0x401da0, 0x6093f8, 0x609280, 6)                                                                                 = 0
__cxa_atexit(0x406b50, 0x6093c0, 0x609280, 4)                                                                                 = 0
__cxa_atexit(0x4050c2, 0x6093e0, 0x609280, 5)                                                                                 = 0
_ZNSaIcEC1Ev(0x7fff40725a70, 0x7fff40725b88, 0x7fff40725b98, 6)                                                               = 0x7fff40725a70
_ZNSsC1EPKcRKSaIcE(0x7fff40725a20, 0x406d72, 0x7fff40725a70, 6)                                                               = 0xa0d028
```

```
$ ltrace -C ./knockedupd
__libc_start_main(0x404497, 1, 0x7ffd5905a698, 0x406ba0 <unfinished ...>
std::ios_base::Init::Init()(0x6093f8, 0xffff, 0x7ffd5905a6a8, 3)                                                              = 0
__cxa_atexit(0x401da0, 0x6093f8, 0x609280, 6)                                                                                 = 0
__cxa_atexit(0x406b50, 0x6093c0, 0x609280, 4)                                                                                 = 0
__cxa_atexit(0x4050c2, 0x6093e0, 0x609280, 5)                                                                                 = 0
std::allocator<char>::allocator()(0x7ffd5905a580, 0x7ffd5905a698, 0x7ffd5905a6a8, 6)                                          = 0x7ffd5905a580
std::basic_string<char, std::char_traits<char>, std::allocator<char> >::basic_string(char const*, std::allocator<char> const&)(0x7ffd5905a530, 0x406d72, 0x7ffd5905a580, 6) = 0x660028
```

