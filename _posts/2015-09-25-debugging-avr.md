---
layout: post
title: Debugging AVR
category: reversing
---


AVR Studio와 hapsim을 이용하면 윈도우에서 AVR프로그램의 시뮬레이션 및 디버깅을할 수 있다.

## 1. AVR Studio 4

AVR Studio는 Amtel에서 배포하는 공식 AVR IDE이다. 최신 버전은 6인데 해본 결과 시뮬레이션이 잘 되지 않았다. 오히려 구 버전인 AVR Studio 4가 잘 되었다. 필자는 4.19버전을 사용해 보았다.

무료이며, 공식 홈페이지 (<http://www.atmel.com/tools/STUDIOARCHIVE.aspx>)에서 다운받을 수 있다.

![avrstudio_open](/assets/2015/09/avrstudio_open.png)

우선 ELF파일을 AVR Studio에서 연다. AVR Studio를 켜면 처음에 위와 같은 화면이 나오는데, 여기서 Open을 눌러 ELF파일을 열면 된다. 그 다음 프로젝트 파일을 저장할 곳을 고르고, 디버그 옵션으로 AVR Simulator를 선택한다. 그러면 시뮬레이터 화면이 켜진다.

## 2. hapsim

그런데 AVR Studio만 가지고는 UART로 나오는 터미널 입출력을 테스트할 수 없다. 그래서 hapsim(<http://www.helmix.at/hapsim/>)이라는 프로그램이 필요하다. hapsim은 실행 중인 AVR Studio에 자동으로 연결하여 다양한 I/O 인터페이스 역할을 해준다.

AVR Studio가 켜진 상태에서 hapsim을 켜고 File > New Control > Terminal을 선택하여 새 터미널 창을 띄운다. 그 다음 Options > Terminal Settings을 선택하여 Local Echo를 체크해준 뒤 USART0이나 USART1을 선택한다.

![hapsim](/assets/2015/09/hapsim.png)

이제 AVR Studio에서 시뮬레이션을 시작하면 hapsim 창에 출력이 보일 것이다.

![avrstudio_done](/assets/2015/09/avrstudio_done.png)

