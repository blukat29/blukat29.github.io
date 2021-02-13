---
layout: post
title: Golang-like Defer in C++
category: dev
---

한동안 Go와 C++을 오가며 프로그램을 짰는데, Go의 `defer`를 C++에 도입하면 편하겠다는 생각이 들어서 인터넷을 뒤져서 [구현하는 법을 찾았다](https://stackoverflow.com/a/42060129/8939955). 이런식으로 사용할 수 있다.

```cpp
FILE* fp = fopen("hello.txt");
defer{ fclose(fp); };
```

스마트 포인터가 정석이라고들 하지만 defer 문법이 직관적이라는 생각에 현재 프로젝트에 사용하고 있다. 약간의 공부를 하면서 배운 다양한 리소스 해제 방법을 정리해두려고 한다.

- Go Defer
- C++ Smart Pointers
    - Pointer Ownership
    - Non-memory Resources
    - Interfacing with Regular Pointer Code
- C++ Defer
    - ScopeGuard
    - Syntactic Sugar
- Conclusion

<!--more-->

# Go Defer

Go는 garbage collected 언어라서 동적할당된 메모리를 해제할 필요가 없다. 그러나 파일이나 소켓같은 리소스는 프로그램 로직에 따라 해제해야 한다. 이때 권장되는 방법은 `defer` (뒤로 미룬다는 뜻) 라는 키워드를 사용하는 것이다. defer는 프로그램이 스코프를 빠져나갈 때 expression을 하나 실행할 수 있게 해준다. 이 방식을 쓰면 리소스 할당 코드와 해제 코드가 붙어있어서 리소스를 해제를 빼먹지 않게 된다.

```go
var mu sync.Mutex
var counter int

func increment() {
    mu.Lock()
    defer mu.Unlock()

    counter++
}
```

# C++ Smart Pointers

C++는 개발자가 직접 동적할당된 메모리를 해제해야 하는데 제대로 하지 못할 경우 메모리 누수 등의 문제가 발생한다. 그래서 C++11부터 `shared_ptr`, `unique_ptr`, `weak_ptr`이 `<memory>` 헤더를 통해 제공되고 있다. 스마트 포인터에 대한 설명은 인터넷에 많으므로 ([1](http://www.tcpschool.com/cpp/cpp_template_smartPointer), [2](https://dydtjr1128.github.io/cpp/2019/05/10/Cpp-smart-pointer.html), [3](https://min-zero.tistory.com/entry/C-STL-1-3-%ED%85%9C%ED%94%8C%EB%A6%BF-%EC%8A%A4%EB%A7%88%ED%8A%B8-%ED%8F%AC%EC%9D%B8%ED%84%B0smart-pointer)) 여기서는 아주 간략하게 설명한다.

스마트 포인터는 일반 포인터를 감싸는 템플릿 클래스인데, 스마트 포인터 객체가 해제되면 그 안에 갖고있던 일반 포인터를 함께 해제하는 식이다. 보통 스마트 포인터는 스택에 할당하니까 스코프를 나갈때 일반 포인터가 자동으로 해제되는 효과를 얻는다.

```cpp
class Car {
  public:
    Car() { printf("ctor "); }
    ~Car() { printf("dtor "); }
    void honk() { printf("honk "); }
};

static void do_honk_car(Car* car) { // regular pointer argument
    car->honk();
}

int main() {
    std::unique_ptr<Car> c(new Car()); // 'c' wraps 'new Car()'

    c->honk(); // Use it like Car* type

    do_honk_car(c.get()); // Get the regular pointer

    // As c is destroyed,
    // the new Car() is automatically destroyed
    return 0;
}

// Output: ctor honk honk dtor
```

## Pointer Ownership

또한 스마트 포인터는 리소스의 오너쉽(ownership) 관리도 세밀하게 할 수 있다.

**`unique_ptr` for singly-owned objects**: unique\_ptr 객체는 포인터의 오너쉽을 갖고다닌다. unique\_ptr을 마지막으로 갖고있는 곳에서 리소스 해제를 담당한다.

```cpp
unique_ptr<Car> make_car() {
    unique_ptr<Car> c(new Car());
    return c; // Car is NOT destroyed. Instead std::move()d
}

int main() {
    unique_ptr<Car> c = make_car();
    c->honk();
    return 0; // Car is destroyed
}
```

**`shared_ptr` for reference counted / shared-ownership objetcts**: shared\_ptr은 내부적으로 레퍼런스 카운팅을 한다. copy될때 카운트가 증가하고 destroy될때 카운트가 감소한다. 카운트가 0이 되면 포인터를 해제한다. [구글 가이드라인](https://google.github.io/styleguide/cppguide.html#Ownership_and_Smart_Pointers)과 [크로미움 가이드라인](https://www.chromium.org/developers/smart-pointer-guidelines)에서는 오너쉽을 파악하기 어려워지고 성능상 불리한 면이 있으므로 꼭 필요할 때만 쓰라고 권장한다.

```cpp
class Noti {
  public:
    void alert(const char* msg) { showMessageBox(msg); }
};

static void long_task(shared_ptr<Noti> noti) {
    very_long_task();
    noti->alert("Job done");
}

static void hard_task(shared_ptr<Noti> noti) {
    if (!very_hard_task()) {
        noti->alert("Job failed");
    } else {
        noti->alert("Job success");
    }
}

int main() {
    shared_ptr<Noti> noti(new Noti());
    long_task(noti);
    hard_task(noti);
    return 0;
}
```

## Non-memory Resources

스마트 포인터는 C++에 기본으로 제공되고 강력한 기능을 갖췄다. 그런데 흠이 있다면 포인터가 아닌 리소스를 관리하기에 (가능은 하지만) 좀 불편하다는 것이다.

오브젝트의 해제 함수가 `delete`나 `free()`가 아닌 경우 custome deleter를 지정해서 스마트 포인터의 자동 해제 기능을 이용할 수 있다. 예컨대 `stdio.h`의  `FILE*`도 여느 C++ 클래스처럼 스택에 할당할 수 있다. 하지만 변수 선언이 상당히 길어져서 읽기가 힘들어진다.

```cpp
bool write_file(const char* msg) {
    // unique_ptr<T, Deleter>
    unique_ptr<FILE, decltype(&fclose)> file(fopen("test.txt", "w"), fclose);
    if (!file)
        return false;

    int len = strlen(msg);
    int n = fwrite(msg, 1, len, file.get());
    return n == len;
}
```

typedef를 쓰면 어느정도 정리할 수 있긴 하다. 그래도 변수를 선언할 때마다 deleter를 명시적으로 넣어주어야 해서 여전히 중복이 있다.

```cpp
typedef std::unique_ptr<FILE, decltype(&fclose)> FilePtr;

int main() {
    FilePtr file(fopen("test.txt", "w"), fclose);
}
```

Wrapper class를 만들 수도 있겠지만 너무 과한 게 아닌가 싶다.

```cpp
class File {
  public:
    File(FILE* fp) : fp_(fp) {}
    ~File() { fclose(fp_); }
    FILE* get() { return fp_; }
  private:
    FILE* fp_;
};

int main() {
    File(fopen("test.txt", "w"));
}
```

게다가 프로그램에서 쓰는 포인터 타입마다 typedef 또는 wrapper class를 만들어 써야 한다는 점도 번거롭다. OpenSSL 라이브러리를 쓰는 프로그램은 [이런 헤더를 만들어 쓰지 않을까](https://stackoverflow.com/a/38079093/8939955).

```cpp
using EC_KEY_ptr = std::unique_ptr<EC_KEY, decltype(&::EC_KEY_free)>;
using EC_GROUP_ptr = std::unique_ptr<EC_GROUP, decltype(&::EC_GROUP_free)>;
using EC_POINT_ptr = std::unique_ptr<EC_POINT, decltype(&::EC_POINT_free)>;
using DH_ptr = std::unique_ptr<DH, decltype(&::DH_free)>;
using RSA_ptr = std::unique_ptr<RSA, decltype(&::RSA_free)>;
using DSA_ptr = std::unique_ptr<DSA, decltype(&::DSA_free)>;
using EVP_PKEY_ptr = std::unique_ptr<EVP_PKEY, decltype(&::EVP_PKEY_free)>;
using BN_ptr = std::unique_ptr<BIGNUM, decltype(&::BN_free)>;
using FILE_ptr = std::unique_ptr<FILE, decltype(&::fclose)>;
using BIO_MEM_ptr = std::unique_ptr<BIO, decltype(&::BIO_free)>;
using BIO_FILE_ptr = std::unique_ptr<BIO, decltype(&::BIO_free)>;
```

## Interfacing with Regular Pointer Code

스마트 포인터는 `operator*` 와 `operator->` 를 구현하여 원 포인터에 접근할 수 있게 해준다. 그러나 포인터 값이 필요할 땐 `get()` 메소드를 불러야 한다. C 라이브러리 함수를 많이 사용한다면 굉장히 귀찮아진다. 아래는 OpenSSL로 RSA 키를 생성하는 예제인데, OpenSSL 함수를 부를 때마다 `ctx.get()` 을 해줘야 한다.

```cpp
EVP_PKEY_CTX_ptr ctx(EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL),
                     EVP_PKEY_CTX_free);
if (!ctx ||
    !EVP_PKEY_keygen_init(ctx.get()) ||
    !EVP_PKEY_CTX_set_rsa_keygen_bits(ctx.get(), 2048) ||
    !EVP_PKEY_keygen(ctx.get(), &pkey)) {
    return -1;
}
```

# C++ Defer

람다 함수를 잘 사용하면 C++ 에서도 Go의 defer 문법을 따라할 수 있다. 어떻게 하는 지는 아래에서 이야기 하겠지만, 일단 된다면 코드가 간단해진다. typedef를 미리 해둘 필요도 없고, `get()` 을 일일히 부를 필요도 없다. `defer{}` 만 추가하면 되기 때문에 새로운 포인터 타입에 대해 적용하기가 간편하다.

```cpp
EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
defer{ EVP_PKEY_CTX_free(ctx); };

EVP_PKEY* pkey = NULL;
if (!ctx ||
    !EVP_PKEY_keygen_init(ctx) ||
    !EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) ||
    !EVP_PKEY_keygen(ctx, &pkey)) {
    return -1;
}
```

## ScopeGuard

[ScopeGuard](https://www.drdobbs.com/cpp/generic-change-the-way-you-write-excepti/184403758)는 2000년에 [Dr. Andrei Alexandrescu](https://en.wikipedia.org/wiki/Andrei_Alexandrescu)가 제시한 템플릿 클래스인데 defer의 원형이 된다고 할 수 있다. 당시에는 람다함수가 없어서 그런지 템플릿에 함수포인터와 인자를 넘기는 식으로 되어있다.

```cpp
FILE* topSecret = fopen("cia.txt");
ScopeGuard closeIt = MakeGuard(fclose, topSecret);
```

Dr. Andrei는 `std::expected<T,E>`([P0323](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0323r9.html))을 제안하기도 했다. [2012강연](https://channel9.msdn.com/Shows/Going+Deep/C-and-Beyond-2012-Andrei-Alexandrescu-Systematic-Error-Handling-in-C), [2018강연](https://www.youtube.com/watch?v=PH4WBuE1BHI)에서 expected와 ScopeGuard에 대한 자세한 설명을 들을 수 있다. expected에 대한 글도 언젠가 한번 쓸 생각이다.

## Syntactic Sugar

C++11 의 람다함수와 매크로, 템플릿을 열심히 사용하면 Go의 문법을 거의 따라할 수 있다.

```cpp
FILE* topSecret = fopen("cia.txt");
defer{ fclose(topSecret); };

BIO* bio = BIO_new_file("pub.pem", "w")
defer{ BIO_free(bio); };
```

요약하자면 람다함수를 멤버로 갖는 구조체를 하나 정의하고 소멸자에서 그 함수를 호출하는 식이다.
구체적인 방법은 아래 Gist에 설명해 두었다.

<script src="https://gist.github.com/blukat29/8b7f07030bab9dc53be7a6290f8e490a.js"></script>

# Conclusion

이럴 땐 스마트 포인터를 쓰는 게 좋다

- Standard C++11 만 사용하고 싶을때
- `new`로 생성한 객체를 간편하게 관리하고 싶을때
- 포인터를 넘기면서 오너쉽(ownership)을 넘기고 싶을 때 - unique\_ptr
- 공유 리소스에 레퍼런스 카운팅을 적용하고 싶을 때 - shared\_ptr

이럴 땐 defer를 쓰는 게 좋다

- C 라이브러리에 일반 포인터를 넘겨야 할 때
- delete가 아닌 방법으로 리소스를 해제해야 할 때
