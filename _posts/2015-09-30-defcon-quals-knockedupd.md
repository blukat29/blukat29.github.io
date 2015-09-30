---
layout: post
title: DEFCON 23 Quals - knockedupd
category: writeup
---

knockedupd는 23회 DEFCON (2015) 예선 리버싱 문제이다.

x86-64 바이너리와 서버 IP가 주어졌다. 서버 포트는 주어지지 않았다.

## 1. 둘러보기

C++로 작성되었고, libpcap을 사용한 프로그램이다.

main()에서는 세 가지 일을 한다.

- `--interface`와 `--config`라는 command line option을 받는다. `--interface`의 기본값은 `en0`이고, `--config`의 기본값은 `knockd.conf`이다.
- `read_config_402C08`를 호출해 config파일을 읽는다
- `start_capture_403FDB`를 호출해 패킷 캡쳐를 준비하고 시작한다.

ltrace 결과 pcap handler가 0x40375d라는 것을 알 수 있었다. pcap handler의 위치는 `start_capture_403FDB`를 리버싱해도 알 수 있다.

```
$ sudo ltrace ./knockupd --interface eth0
  ...
pcap_dispatch(0x1dd50d0, 0xffffffff, 0x40375d, 0)  = 0
pcap_dispatch(0x1dd50d0, 0xffffffff, 0x40375d, 0)  = 0
pcap_dispatch(0x1dd50d0, 0xffffffff, 0x40375d, 0)  = 0
pcap_dispatch(0x1dd50d0, 0xffffffff, 0x40375d, 0)  = 0
pcap_dispatch(0x1dd50d0, 0xffffffff, 0x40375d, 0)  = 0
```

## 2. read_config 분석

config 파일은 rule 여러 개로 이뤄져 있는데, rule의 모양은 다음과 같아야 한다.

```
[GoodRule]
  command=/bin/bash -c "ls -al"
  type=udp
  sequence=123,456,789,1234
  timeout=2000
```

type은 'udp'나 'tcp' 둘 중 하나여야 하고, sequence는 쉼표로 구분된 최대 6개의 정수여야 한다.

```cpp
struct rule {   // size 0x38
  string name;
  string command;
  int sequence_len;
  short sequence_val[6];
  int is_udp;
  int what;
  string filter;
  long long timeout;
};
```

`read_config`는 각 rule을 파싱하여 위와 같은 구조체에 저장한다. 완성된 구조체는 `.bss:0x6093E0`에 있는 전역 vector에 추가된다. 이 변수가 vector라는 것은 `sub_404D04` 안에 `vector::_M_emplace_back_aux`라는 스트링이 있다는 것에서 알 수 있다.

config 파일 파싱이 끝나면 하드코딩된 rule이 두 개 추가된다. 그 내용은 다음과 같다.

```cpp
{
  name = "";
  command = "/bin/bash -c \"/sbin/iptables -I KNOCKEDUPD 1 -s %IP% -p tcp --dport 10785 -j ACCEPT\"";
  sequence_len = 3;
  sequence_val = {13102, 18264, 18282};
  is_udp = 1;
  timeout = 2000;
};

{
  name = "";
  command = "/bin/bash -c \" /sbin/iptables -I KNOCKEDUPD 1 58 -s %IP% -p tcp --dport 9889 -j ACCEPT\"";
  sequence_len = 5;
  sequence_val = {14661, 15148, 39979, 35314, 31717};
  is_udp = 1;
  timeout = 2000;
};
```

## 3. pcap handler 분석

```cpp
void pcap_handler_40375d(char* user, pcap_pkthdr* h, char* data);
```

pcap handler의 prototype은 이렇게 생겼다. 단, data는 ethernet layer부터 시작하는 패킷의 raw data이다.

핸들러는 내부적으로 일종의 session을 관리한다. 각 session item은 다음과 같이 생겼다. 프로그램이 관리하고 있는 세션은 `.bss:0x6093C0`에 있는 벡터에 저장된다.

```cpp
struct session {  // size 0x20
    int rule_idx;
    int sequence_idx;
    time_t last_time;
    string src_ip;
    int is_udp;
}
```

아래는 핸들러의 대략적인 모습이다.

```cpp
vector<rule*> g_rules; // .bss:0x6093E0
vector<session*> g_sessions; // .bss:0x6093C0

void pcap_handler_40375d(char* user, pcap_pkthdr* h, char* data)
{
  if (data->eth->eth_type != ETHTYPE_IP) return;
  if (data->ip->ver != IPv4 || data->ip->ihl != 5) return;

  string* curr_src_ip = new string(inet_ntoa(data->ip->src_ip));

  int curr_is_udp = -1;
  short curr_dst_port;
  if (data->ip->proto == IPPROTO_TCP)
  {
    curr_dst_port = ntohs(data->tcp->dst_port);
    curr_is_udp = 0;
  }
  else if (data->ip->proto == IPPROTO_UDP)
  {
    curr_dst_port = ntohs(data->udp->dst_port);
    curr_is_udp = 1;
  }
  else
    return;

  for (session* s in g_sessions)
  {
    time_t time_delta = current_time() - s->last_time;
    if (time_delta > g_rules[s.related_rule_id]->timeout)
      g_sessions.remove(s);
    if (s.sequence_idx == -1)
      g_sessions.remove(s);
  }

  session* curr_session = NULL;
  for (session* s in g_sessions)
  {
    if (s->src_ip == curr_src_ip)
    {
      curr_session = s;
      break;
    }
  }

  if (curr_session)
  {
    rule* r = g_rules[curr_session->rule_idx];
    int idx = curr_session->sequence_idx;
    if (r->sequence_val[idx-1] != curr_dst_port
     && r->sequence_val[idx] == curr_dst_port)
    {
      curr_session->sequence_idx ++;
      curr_session->last_time = current_time();
      if (curr_session->sequence_idx == r->sequence_len)
      {
        string cmd = (*r->command).replace("%IP%", curr_session->src_ip);
        system(cmd);
        curr_session->sequence_idx = -1;
      }
    }
  }
  else
  {
    for (int i=0; i<g_rules.length(); i++)
    {
      if (g_rules[i]->is_udp == curr_is_udp
       && g_rules[i]->sequence_val[0] == curr_dst_port)
      {
        session* ns = {
          rule_idx = i;
          sequence_idx = 1;
          last_time = current_time();
          src_ip = curr_src_ip;
          is_udp = curr_is_udp;
        };
        g_sessions.push_back(ns);
      }
    }
  }
}
```

## 4. 답 구하기

문제 서버의 13102, 18264, 18282 포트에 순서대로 UDP 패킷을 보내면

```
/bin/bash -c "/sbin/iptables -I KNOCKEDUPD 1 -s %IP% -p tcp --dport 10785 -j ACCEPT"
```

이 명령이 실행되어 10785번 포트가 열린다. 그 포트로 TCP 접속을 하면 정답을 준다.

```py
import socket

def send_data(data, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(data, ('52.74.114.1', port))

send_data("hihi", 13102)
send_data("hihi", 18264)
send_data("hihi", 18282)
```

```
$ nc 52.74.114.1 10785
The flag is: 'Kn0ck kn0ck, Wh0 it is?'
```

또 다른 기본 rule인 14661, 15148, 39979, 35314, 31717 포트는 다른 문제와 관련이 있었다.


