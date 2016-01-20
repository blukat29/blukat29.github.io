---
layout: post
title: Holyshield 2016 - Holy Cat writeup
category: writeup
---

[Go](https://golang.org/)가 핫하긴 한가보다. Holy Cat (Reversing, 250)은 이번 Holyshield 2016에 출제된 윈도우용 Go 바이너리 리버싱 문제다. exe파일과 서버 IP를 줬는데, 아마 이 exe파일이 어떤 웹서버인 듯 하다.

## 1. 일단 실행

일단 윈도우 VM에서 프로그램을 실행해보니, 방화벽 경고가 떴다. 역시 네트워크로 뭔가를 하나보다. `netstat`으로 확인해 보니 `0.0.0.0:9999   LISTEN`이 있었다. 브라우저로 `localhost:9999`에 접속해 보니 404 not found가 나왔다. 이제 코드를 볼 차례다.

제일 먼저 프로그램 내에 있는 string 중에서 `/`로 시작하는 것들을 찾았다. `/login`, `/login_check`, `/debug_server_status` 세 개가 있었다. 브라우저로 들어가 보니 `/login` 페이지에는 패스워드 입력창 하나가, `/login_check`에는 "Access Denied" 메시지, `/debug_server_status`에는 이런 메시지가 나왔다.

```
--------------DEBUG INFO--------------
GET
127.0.0.1:49175
Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.111 Safari/537.36
1488
1453030681
blukat-PC
```

세 번째 줄은 브라우저의 IP와 포트인 것 같고 (이 경우엔 IPv6 loopback 주소인 ::1), 그 다음 브라우저의 User-Agent, 알수없는 1488, 현재 타임스탬프, 그리고 컴퓨터 이름이 나왔다. 1488은 이리 저리 생각하다가 작업관리자를 켜서 holycat.exe의 PID라는 것을 알아냈다. 이 값들을 조합하면 맞는 비밀번호가 되는 식인 것 같다.

## 2. 코드 분석

바이너리를 열어보았는데 심볼이 없어서 좀 불편했다. 그래서 `<body>`나 `Access Denied`같은 문자열로부터 역추적하여 각 URL에 해당하는 request handler를 찾았다. `Login_Check_4019D0`, `Access_Denied_401330`, `Debug_Server_Status_401CF0`, `Show_Key_401430` 등이다.  `Login_Check` 함수는 여러 라이브러리 함수들을 호출하기 때문에 그 역할을 알아내는 것이 중요했다.

[Go http tutorial](https://golang.org/pkg/net/http/)에 따르면 HTTP handler는 `handler(w ResponseWriter, r *Request)` 형태이다. 그 중에서 Request 구조체는 [request.go](https://golang.org/src/net/http/request.go) 파일에 정의되어 있는데,  Ollydbg에서 잘라낸 메모리 값과 비교해 보니 다음과 같았다. 메모리를 분석하는 데에 [Go Data Structures](http://research.swtch.com/godata)문서가 도움이 되었다.

```
12578A10  1259C580  ASCII "POST /login_check HTTP/1.1" + 0: Method.Data
12578A14  00000004                                     + 4: Method.Len
12578A18  12536980                                     + 8: *URL
12578A1C  1259C592  ASCII "HTTP/1.1"                   + c: Proto.Data
12578A20  00000008                                     +10: Proto.Len
12578A24  00000001                                     +14: ProtoMajor
12578A28  00000001                                     +18: ProtoMinor
12578A2C  1259C5A0                                     +1c: Header
12578A30  00375430                                     +20: Body.Reader
12578A34  125326F0                                     +24: Body.Closer
12578A38  0000000D                                     +28: Contentlength
12578A3C  00000000                                     +2c: TransferEncoding
12578A40  00000000
12578A44  00000000
12578A48  00000000
12578A4C  00000000                                     +3c: Close
12578A50  12538F70  ASCII "localhost:9999"             +40: Host.Data
12578A54  0000000E                                     +44: Host.Len
12578A58  00000000                                     +48: Form
12578A5C  00000000                                     +4c: PostForm
12578A60  00000000                                     +50:
12578A64  00000000                                     +54: Trailer
12578A68  12538F30  ASCII "[::1]:49339"                +58: RemoteAddr.Data
12578A6C  0000000B                                     +5C: RemoteAddr.Len
12578A70  1259C585  ASCII "/login_check HTTP/1.1"      +60: RequestURI.Data
12578A74  0000000C                                     +64: RequestURI.Len
12578A78  00000000
```

`sub_401040`는 `Request.RemoteAddr`를 입력받고, 내부에서 `%d.%d.%d.%d:%d`라는 문자열을 사용하는 걸로 보아 클라이언트 주소를 파싱하는 부분인 듯 싶었는데, 로컬에서 테스트할 때 클라이언트 IP가 `::-1`로 나와서 오류가 났다. 처음에 여기서 엄청 헤맸다. 그래서 [이 글](http://superuser.com/questions/586144/disable-ipv6-loopback-on-windows-7-64-bit)을 참고하여 윈도우 Loopback 주소를 `127.0.0.1`로 바꿔주었다.

`sub_486fd0`는 `Debug_Server_Status`의 출력과 비교해가면서 알아냈는데, Go의 `time.Now()`이다. `Login_Check`에는 이 외에도 `Request.Method`가 POST인지 체크하는 부분과 password로 받은 값을 `ParseInt`에 넘기는 부분 등이 있다.

이 두 함수에서 나온 값을 합친 뒤 `sub_4afe20`에 넘기면 올바른 비밀번호가 나온다. 두 값을 합치는 과정은 다음과 같다.

```py
a,b,c,d,p = (127, 0, 0, 1, 65461)  # 127.0.0.1
h = (((a^0x80 + b) ^ 0x88) << 3;
h += c + d
h *= p

t = 1452794845 / 60
t += 1

print hex(h^t)
```

## 3. 답 구하기

문제 서버에 접속해서 `/debug_server_status`에서 나의 주소와 서버 시간을 얻어낸 다음 위 코드로 중간값을 생성한다. 그 다음 로컬에서 OllyDbg에서 `sub_4afe20`에 브레이크를 걸고 파라미터를 방금 얻은 값으로 바꾸고 실행하면 맞는 비밀번호가 나온다. 고맙게도 시간을 분 단위까지만 사용하기 때문에 그 안에 비밀번호를 서버에 입력하면 키를 받을 수 있다.

```
Login OK
KEY IS "A11 I W4nt for chr1stma5 i5 Y0u."
```

