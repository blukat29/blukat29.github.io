---
layout: post
title: Docker Buildkit 으로 빌드 시간 단축하기
category: dev
---

Docker의 multi-stage build와 buildkit을 이용하여 복잡한 빌드의 시간을 단축하는 방법.

이 방법을 사용하면 덤으로 멋있는 빌드 화면을 볼 수 있다.

<video muted autoplay loop style="width:100%">
    <source src="/assets/2021/07/buildkit-cross.mp4" type="video/mp4" />
</video>

<!--more-->

# 탐구 계기

약 4년 전에 예전에 만들어 두었다가 방치한 [docker-cross](https://github.com/blukat29/docker-cross) 라는 도커 이미지 프로젝트를 업데이트 하려고 했다. docker-cross는 20가지가 넘는 아키텍처의 바이너리를 분석할 수 있는 크로스-디버거 모음집이다. 컴파일러는 없고 디버거만 빌드해 두었다. 당시에 [SECCON 2016 해킹대회](https://ctftime.org/event/401) 본선에 준비하면서 만들었던 것으로 기억한다.

그러다 GitHub에 어떤 분이 이미지의 데비안 OS 버전을 최신으로 올려달라고 했다. 빌드를 해보니 한 시간이 넘게 걸렸다. 그런데 얼마 전에 multi-stage build라는 것을 접한 것이 기억나 적용해보기로 했다.

# Multi-stage build

도커의 multi-stage build 개념은 간단히 설명하자면 하나의 Dockerfile에 여러개의 (중간) 이미지를 정의하고, 이미지끼리 빌드 결과물을 복사할 수 있는 기능이다.

예를 들어 하나의 Dockerfile에 개발환경 이미지 하나, 배포용 이미지 하나를 만들 수 있다. 개발환경 이미지에서는 컴파일러를 설치하고 프로그램을 빌드한다. 배포용 이미지는 깨끗한 OS 이미지에서 시작해서 빌드된 바이너리만 개발환경 이미지로부터 복사해온다. 이렇게 하면 개발환경 이미지에서 용량을 줄이기 위한 기법을 사용하지 않아도 되니 개발이 한결 수월해진다.

자세한 사용법과 옵션은 [도커 매뉴얼](https://docs.docker.com/develop/develop-images/multistage-build/)에 잘 설명돼있다.

## Before multi-stage build

이전에는 빌드된 이미지의 크기를 줄이려고 빌드 단계의 갯수(레이어)를 줄이거나, 아예 빌드용/배포용 Dockerfile을 따로 만들기도 했다.

아래는 각 빌드 단계가 최소한의 파일만 추가하도록 하는 기법이다. 도커 매뉴얼에서도 "Minimize the number of layers"라고 best-practice 중의 하나로 [소개하고 있다](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#minimize-the-number-of-layers). 이렇게 하면 이미지에 빌드 결과물만 포함된다.

```docker
FROM ubuntu:18.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential cmake wget texinfo libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/name/myapp \
    && cd myapp \
    && ./configure \
    && make -j $(nproc) \
    && make install \
    && cd .. \
    && rm -rf myapp
```

문제는 커맨드 중간에 에러가 났을 경우에 고치려면 시간이 오래 걸린다는 것이다. 스크립트 오류를 한 줄 고친 다음에는 여러 줄에 걸친 RUN 커맨드를 다시 실행해야 하기 때문이다. [어떤 경우](https://github.com/grpc/grpc-docker-library/blob/master/1.21.0/cxx/Dockerfile)에는 RUN 커맨드 하나가 10분이 넘게 걸릴 정도로 커지기도 한다.

빌드용과 배포용 Dockerfile을 따로 만드는 경우에는 단계 수에 구애받지 않고 자유롭게 빌드 스크립트를 작성할 수 있다.

```docker
# Dockerfile.build
FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y wget build-essential   # tools
RUN apt-get install -y texinfo libncurses-dev # dependencies

RUN git clone https://github.com/name/myapp
RUN cd myapp \
    && ./configure --prefix=/opt/myapp \
    && make -j $(nproc) \
    && make install
```

```docker
# Dockerfile
FROM ubuntu:18.04

COPY myapp /opt
CMD ["/opt/myapp/bin/app"]
```

그렇지만 이러면 빌드 과정이 좀 복잡해진다

1. Dockerfile.build로 `myapp:builder` 이미지를 빌드
2. docker run으로 `myapp:builder` 이미지를 실행
3. docker cp로 빌드 결과물을 컨테이너 밖으로 복사
4. Dockerfile로 빌드 결과물이 포함된 `myapp:latest` 이미지를 빌드

```bash
# build.sh
docker build -t myapp:builder -f Dockerfile.build .

docker run --name result myapp:builder
docker cp result:/opt/myapp ./myapp
docker rm -f result

docker build --no-cache -t myapp:latest .
rm -r ./myapp
```

게다가 이미지가 두 개씩 생겨서 docker images 목록이 더 혼잡해질 것이다.

## Use multi-stage build

Multi-stage build 기능을 쓰면 빌드용과 배포용 이미지를 한 Dockerfile에 작성할 수 있다.

```bash
# Dockerfile

# Define the first stage and name it 'builder'
FROM ubuntu:18.04 AS builder

RUN apt-get update
RUN apt-get install -y build-essential wget texinfo libncurses-dev

RUN wget http://ftp.gnu.org/gnu/gdb/gdb-10.2.tar.xz
RUN tar xf gdb-10.2.tar.xz
RUN cd gdb-10.2 \
    && ./configure --prefix=/opt/myapp \
    && make -j $(nproc) \
    && make install

# Start the second stage from a clean image
FROM ubuntu:18.04
# copy the build artifacts only
COPY --from=builder /opt/myapp /opt/myapp
CMD ["/opt/myapp/bin/app"]
```

첫번째 stage의 `FROM .. AS builder` 는 첫번째 stage로 만들어지는 (임시) 이미지의 이름을 builder로 정하고 뒤에서 참조할 수 있도록 한다. 두번째 stage의 `COPY --from=builder ..` 는 첫번째 이미지에서 일부 파일만 복사하는 명령이다. 위 예시에서는 빌드 결과물을 복사하고 있다. 빌드용과 배포용 Dockerfile을 따로 작성했을 때와 결과적으로 같지만 훨씬 깔끔한 방법이다.

Multi-stage build 에서는 각 stage가 다른 base image로부터 시작할 수 있기 때문에 여러 언어를 쓰는 프로젝트나, 여러 환경을 지원하는 경우에 유용할 수 있다.

아래는 C++과 Go를 사용하는 프로젝트의 빌드 예시이다.

```bash
# Dockerfile

FROM ubuntu:18.04 AS build-cpp
RUN apt-get update && apt-get install -y build-essential
COPY src/cpp .
RUN gcc -o libfoo.so -shared foo.c

FROM golang:1.16 AS build-go
COPY src/go .
RUN go build -o app

FROM debian:buster
COPY --from=build-cpp libfoo.so .
COPY --from=build-go app .
```

stage들 간의 상관관계를 아래와 같이 그릴 수 있다.

![docker-graph1.png](/assets/2021/07/docker-graph1.png)

# Parallel stages with Buildkit

그런데 바로 전 그림을 보면 왠지 build-cpp와 build-go stage를 병렬로 실행할 수 있을 것 같지 않은가? 그렇다. 두 stage는 서로 독립적이니 병렬로 빌드할 수 있다. 빌드할 때 환경변수를 하나 추가해주면 된다.

```bash
DOCKER_BUILDKIT=1 docker build -t myapp .
```

출력이 평소 보던 것과 많이 다를 것이다. Docker 18.09부터 추가된 [Buildkit](https://docs.docker.com/develop/develop-images/build_enhancements/)이라는 빌드 엔진을 사용했기 때문이다.

![buildkit-slide.png](/assets/2021/07/buildkit-slide.png)

Buildkit을 사용하면 병렬 빌드 외에도 장점이 여러가지 있다고 한다 ([참고1](https://blog.siner.io/2020/03/29/dockerfile-buildkit/), [참고2](https://www.docker.com/blog/advanced-dockerfiles-faster-builds-and-smaller-images-using-buildkit-and-multistage-builds/))

## Trying out BuildKit

아래와 같은 multi-stage Dockerfile을 작성해보자.

```bash
# Dockerfile
FROM debian:buster AS s1
RUN sleep 11
RUN echo 1111 > /opt/one

FROM debian:buster AS s2
RUN sleep 12
RUN echo 2222 > /opt/two

FROM debian:buster
COPY --from=s1 /opt /opt
COPY --from=s2 /opt /opt
```

기본 방식으로 빌드하면 약 30초가 소요되었다. 각 스테이지를 순차적으로 실행하기 때문이다.

```bash
$ time docker build -t test .
Sending build context to Docker daemon  22.02kB
Step 1/9 : FROM debian:buster AS s1
 ---> 7a4951775d15
Step 2/9 : RUN sleep 11
 ---> Running in 3fbe4462e3e1

..

Step 9/9 : COPY --from=s2 /opt /opt
 ---> d1caa208733c
Successfully built d1caa208733c
Successfully tagged test:latest

real    0m31.971s
user    0m0.032s
sys     0m0.036s
```

BuildKit 방식으로 빌드하면 약 16초가 소요되었다.

```bash
$ DOCKER_BUILDKIT=1 docker build -t test .
[+] Building 16.6s (11/11) FINISHED
 => [internal] load .dockerignore                                                              0.0s
 => => transferring context: 2B                                                                0.0s
 => [internal] load build definition from Dockerfile                                           0.1s
 => => transferring dockerfile: 242B                                                           0.0s
 => [internal] load metadata for docker.io/library/debian:buster                               0.0s
 => CACHED [s2 1/3] FROM docker.io/library/debian:buster                                       0.0s
 => [s1 2/3] RUN sleep 11                                                                     12.8s
 => [s2 2/3] RUN sleep 12                                                                     14.3s
 => [s1 3/3] RUN echo 1111 > /opt/one                                                          2.4s
 => [s2 3/3] RUN echo 2222 > /opt/two                                                          2.0s
 => CACHED [stage-2 2/3] COPY --from=s1 /opt /opt                                              0.0s
 => CACHED [stage-2 3/3] COPY --from=s2 /opt /opt                                              0.0s
 => exporting to image                                                                         0.0s
 => => exporting layers                                                                        0.0s
 => => writing image sha256:1426b5b4d30f0d199655f94cb2752c004618bff9d3bb2deb989ed030a632e7c8   0.0s
 => => naming to docker.io/library/test                                                        0.0s
```

# docker-cross 최적화

docker-cross는 빌드한 바이너리만 2~4GB에 달하는 커다란 이미지다. 그만큼 빌드도 오래 걸린다. 최적화 전의 Dockerfile은 [이렇게](https://github.com/blukat29/docker-cross/blob/4d3cba764ca88f79229c351fbdb39e487c8dce2d/Dockerfile) 생겼는데, 대부분의 빌드 커맨드가 RUN 하나에 들어있는 모양이다. 만약 여기에 지원 아키텍처를 추가한다거나 하면 한참동안 다시 빌드를 해야 한다.

최적화 후에는 [이렇게](https://github.com/blukat29/docker-cross/blob/a5320b5c5113e8a29c2ff99d1aef7b1a703e6136/Dockerfile) 생겼는데, stage간의 관계를 그림으로 그리면 아래와 같다.

![docker-graph2.png](/assets/2021/07/docker-graph2.png)

최적화 이전에는 아무리 `make -j` 옵션을 주더라도 돌려도 중간중간 한 코어만 돌아가는 시간이 꽤 많았는데, 최적화 이후에는 지속적으로 CPU의 모든 코어를 활용하는 모습을 볼 수 있었다.

# References

- [https://stackoverflow.com/questions/61935684/is-it-possible-to-docker-build-a-multi-staged-image-in-parallel](https://stackoverflow.com/questions/61935684/is-it-possible-to-docker-build-a-multi-staged-image-in-parallel)
- [https://medium.com/@tonistiigi/advanced-multi-stage-build-patterns-6f741b852fae](https://medium.com/@tonistiigi/advanced-multi-stage-build-patterns-6f741b852fae)
- [https://www.docker.com/blog/advanced-dockerfiles-faster-builds-and-smaller-images-using-buildkit-and-multistage-builds/](https://www.docker.com/blog/advanced-dockerfiles-faster-builds-and-smaller-images-using-buildkit-and-multistage-builds/)
- [https://blog.siner.io/2020/03/29/dockerfile-buildkit/](https://blog.siner.io/2020/03/29/dockerfile-buildkit/)
- [https://velog.io/@seheon99/Dockerfile-작성-방법-12](https://velog.io/@seheon99/Dockerfile-%EC%9E%91%EC%84%B1-%EB%B0%A9%EB%B2%95-12)
- [https://docker.apachezone.com/blog/7?page=8](https://docker.apachezone.com/blog/7?page=8)
