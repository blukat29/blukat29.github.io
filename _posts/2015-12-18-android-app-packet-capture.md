---
layout: post
title: 안드로이드 앱 패킷 캡쳐하기
category: reversing
---

디버깅이나 리버싱을 하기 위해 앱에서 나가거나 앱으로 들어오는 패킷을 봐야 할 때가 있다. 그럴 때 tcpdump와 socat을 사용하면 앱과 서버 사이에 오가는 HTTP, HTTPS 패킷을 볼 수 있다.

## 준비물

- 안드로이드 폰 (루팅 필요 없음) or 에뮬레이터
- 우분투 서버 (루트 권한 필요)

## 1. 우분투에 PPTP VPN 서버 설치

<https://wordpress.update.sh/archives/16>


## 2. 안드로이드에서 VPN 서버에 접속

안드로이드 환경설정 안에 VPN 설정에 들어가서. 1에서 설정한 아이디와 비밀번호로 접속한다. 접속에 성공하면 먼저 인터넷이 되는지 확인하고, 그 다음 <https://www.whatismyip.com/> 같은 사이트에서 자신의 IP가 우분투 서버의 IP로 나오는 것을 확인한다.


## 3. tcpdump로 HTTP 캡쳐

tcpdump는 간편하고 가볍지만 https로 오가는 데이터를 볼 수 없다.

### 3.1. 설치

```
sudo apt-get install tcpdump
```

### 3.2. 캡쳐

```
sudo tcpdump -i ppp0
```

* `ppp0`은 PPTP로 접속한 첫 번째 접속자에 할당되는 가상 인터페이스다. 접속자 수가 늘어나면 인터페이스 이름이 `ppp1`, `ppp2`... 와 같이 할당된다.

```
sudo tcpdump -i ppp0 -A -s 0 tcp port 80
```

* `-A`: 패킷 내용을 아스키로 출력. `-X`를 쓰면 hexdump를 출력한다.
* `-s 0`: 패킷이 아무리 길어도 전체를 출력.
* `tcp port 80`: 포트가 80번인 패킷만 선택.

```
sudo tcpdump -i ppp0 -A -s 0 tcp port 80 and host 1.2.3.4
```

* `host 1.2.3.4`: 출발지나 목적지가 `1.2.3.4`인 것만 선택.

```
sudo tcpdump -i ppp0 -A -s 0 tcp port 80 and host 1.2.3.4 and '(((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```

* 뒤의 복잡한 식은 TCP payload가 있는 패킷만 골라내는 필터이다.


## 4. socat으로 HTTPS 캡쳐

man-in-the-middle(MITM) 공격을 하여 오가는 HTTPS 패킷을 복호화한다. 하나의 IP로 가는 패킷만 볼 수 있다. 설정이 좀 복잡하다.

### 4.1. 설치

```
sudo apt-get install openssl socat
```

### 4.2. Self-signed 인증서 생성

CA 인증서와 서버 인증서를 만들고, CA인증서로 서버 인증서를 서명하여 self-signed certificate를 만든다.

```
openssl genrsa -aes256 -out ca.key 4096
```

* CA의 키(`ca.key`)를 생성한다. 이때 CA용 비밀번호를 하나 정한다.

```
openssl req -new -x509 -days 365 -key ca.key -out ca.crt
```

* CA 인증서(`ca.crt`)를 생성한다. 방금 정한 비밀번호를 입력한다. 그 뒤쪽 추가 정보는 입력하지 않고 엔터만 쳐도 된다.

```
openssl genrsa -aes256 -out server.key 4096
```

* 서버의 키(`server.key`)를 생성한다. 이때 서버용 비밀번호를 하나 정한다.

```
openssl req -new -key server.key -out server.csr
```

* 서버 인증서(`server.csr`)를 생성한다. 방금 정한 비밀번호를 입력한다. 다른 정보는 엔터만 쳐서 넘어가도 되지만, Common Name(CN)은 꼭 앱과 통신하는 원래 서버의 도메인을 적어야 한다.

```
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```

* 마지막으로, CA인증서로 서명한 서버 인증서(`server.crt`)를 만든다. 아까 정한 CA용 비밀번호를 사용한다.

### 4.3. 안드로이드에 CA인증서 등록

아까 만든 CA인증서 파일 `ca.crt`를 안드로이드의 trusted CA storage에 추가한다.

### 4.4. 캡쳐

먼저 VPN을 통해 목표 서버로 가는 HTTPS 패킷을 4443번 포트로 리다이렉트 시킨다.

```
sudo iptables -t nat -A PREROUTING \
    -i ppp+ -p tcp -d github.com --dport 443 \
    -j REDIRECT --to-port 4443
```

그 다음 socat을 이용해 패킷을 본다.

```
export CERT="cert=server.crt,key=server.key,cafile=ca.crt"
export SSL="cipher=AES128-SHA,method=TLSv1"
sudo socat -v OPENSSL-LISTEN:443,reuseaddr,verify=0,$CERT,$SSL,debug,fork \
    "EXEC:'openssl s_client -quiet -connect github.com:443'"
```

`Enter PEM pass phrase:`가 나오면 서버 인증서의 비밀번호를 입력한다.

`CERT`는 아까 만든 self-signed 인증서 파일의 위치이다. `SSL`은 socat이 사용할 알고리즘을 강제헤주는 부분인데, 이 옵션이 빠져있을 경우 SSL 설정이 취약하다면서 브라우저에서 연결을 포기하는 경우가 있다.

### 4.5. Troubleshooting

브라우저로 접속했을 때 "해당 웹페이지를 사용할 수 없음"이라거나 `ERR_CONNECTION_REFUSED`같은 메시지를 보여주고, socat에서는 `2015/12/27 08:12:25 socat[24422] E SSL_accept(): socket closed by peer`를 출력하고 뻗었다면, socat 옵션에서 `fork`를 빼먹었는지 확인해야 한다. socat은 패킷을 딱 하나만 캡쳐하고 종료하기 때문에 `fork`옵션을 넣어서 계속 캡쳐하도록 만들어야 한다.

브라우저에서 Diffie-Hellman 공개 키 어쩌구 그러거나 `ERR_SSL_WEAK_SERVER_EPHEMERAL_DH_KEY`같은 메시지가 나온다면 socat의 SSL알고리즘 설정이 약한 것이다. 브라우저에 따라 그냥 "웹페이지를 표시할 수 없습니다"라고 하고 마는 경우도 있으니 주의. 이럴 땐 `cipher=`옵션을 고쳐서 최신 권고안에 맞는 것을 사용하도록 한다.

## 참고

- <https://wordpress.update.sh/archives/16>
- <https://sites.google.com/site/jimmyxu101/testing/use-tcpdump-to-monitor-http-traffic>
- <http://sleeplesscoding.blogspot.kr/2011/01/using-tcpdump-to-sniff-http-traffic.html>
- <http://www.akadia.com/services/ssh_test_certificate.html>
- <http://www.myhowto.org/java/81-intercepting-and-decrypting-ssl-communications-between-android-phone-and-3rd-party-server/>
- <http://security.stackexchange.com/questions/33374/whats-an-easy-way-to-perform-a-man-in-the-middle-attack-on-ssl>

