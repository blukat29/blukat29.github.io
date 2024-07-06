---
layout: post
title: GPT시대, 코딩기술자의 쇠퇴를 생각하며 를 읽고
category: uncategorized
---

우연히 좋은 글을 읽었습니다. [GPT시대, 코딩기술자의 쇠퇴를 생각하며 (번역)](https://smallake.kr/?p=33562).

원문은 뉴요커 매거진의 [A Coder Considers the Waning Days of the Craft](https://www.newyorker.com/magazine/2023/11/20/a-coder-considers-the-waning-days-of-the-craft). 제목의 'Wane'은 영어로 달의 이지러짐 등을 표현할 때 쓰는 약해지다, 줄어들다, 시들해진다는 뜻이라고 합니다 ([사전](https://en.dict.naver.com/#/entry/enko/ba07d4148d06436f928d8296c971f85a))

인공지능과 프로그래밍에 대한 에세이인데 흥미로운 대목이 많아서 글로써 기억해두려고 합니다.

재밌었던 부분 중 하나는 Dijkstra 교수님이 무려 1978년에 <자연어로 프로그래밍하는 것의 어리석음에 대하여 ([On the foolishness of "natural language programming"](https://www.cs.utexas.edu/~EWD/transcriptions/EWD06xx/EWD667.html))>란 글을 남기셨다는 점입니다. 앞서나가셨던 걸까요, 그 당시 연구 트렌드였던 걸까요. 그것도 아니면 COBOL같은 문장식의 프로그래밍 언어를 보고 말씀하신 걸까요. ([SO: What programming language is most like natural language?](https://stackoverflow.com/questions/491971/what-programming-language-is-most-like-natural-language))

```
100200 MAIN-LOGIC SECTION.
100300 BEGIN.
100400     DISPLAY " " LINE 1 POSITION 1 ERASE EOS.
100500     DISPLAY "Hello world!" LINE 15 POSITION 10.
100600     STOP RUN.
100700 MAIN-LOGIC-EXIT.
100800     EXIT.
```

SO 댓글에 이런 말도 있네요. 한 30년이 지나면 COBOL 자리에 ChatGPT가 들어간 문장이 돌아다닐까요?

> I heard that when COBOL was released, many people expected that there would be no more professional programmers within a few years - since obviously, COBOL was so easy to use that anyone who needed a program could write it themselves.

<!--more-->

하여간 1978년 글에서 프로그래밍 언어란 "자연어를 사용할 때 필연적으로 겪는 온갖 넌센스를 배제하는 도구"라면서 프로그래밍 언어를 써야만이 컴퓨터의 강점인 정확성(precision)을 가져갈 수 있다고 주장합니다.

> Formal programming languages, he wrote, are “an amazingly effective tool for ruling out all sorts of nonsense that, when we use our native tongues, are almost impossible to avoid.”

그런데 조금 더 생각해보면, GPT가 프로그램을 자연어로 짜는게 아니라 GPT에게 프로그램 명세를 자연어로 전달하는 것일 뿐 결국 출력되는 건 구체적인(concrete) 프로그래밍 언어니까 약간 다른 맥락인것 같기도 합니다. 지금도 사람에게 프로그램 명세를 자연어로 전달하면 프로그래밍 언어로 쓰여진 소프트웨어가 나오는데 사람의 역할을 AI가 한다는 점만 다르니까요. 자연어 프로그래밍이라는 행위를 더 분해해봐야겠습니다.

- A. Natural language programming
  - Dumb machine (compiler) interprets the (possibly ambiguous) natural language to machine instructions
- B. AI programming
  - AI (LLM) interprets the (possibly ambiguous) natural language to formal program -- we can concretize here
  - Dumb machine (compiler) interprets the formal program to machine instructions
- C. Human-AI interface
  - AI (LLM) interprets the (possibly ambiguous) natural language to machine instructions, or directly execute it.

다익스트라 교수님이 지적한대로 A(e.g. COBOL)와 C(e.g. Apple Siri)의 경우 "자연어로 프로그래밍하는 것"이 자연어의 모호함 때문에 어려울 수 있지만, B의 경우에서처럼 오늘날의 "GPT로 프로그래밍하는 것"은 생성된 프로그램을 검토하고 수정하고 테스팅할 수 있으니 여전히 유효한 방법이라고 생각합니다. 그러니 자연어의 모호함 때문에 AI가 프로그래밍 현장에서 배제될 것 같지는 않습니다.

---
<br/>
전자식 컴퓨터 이전에 '컴퓨터'란 말은 '계산원'이라는 직업을 가리키는 단어였다는 이야기는 들어본 적 있습니다 ([Computer (occupation)](https://en.wikipedia.org/wiki/Computer_(occupation))). 언젠가는 '코더'라는 단어의 뜻이 바뀔까요. 코더라는 직업이 기계로 대체된 미래에는 키보드로 치는 코딩을 어떻게 바라볼까요. 피라미드를 사람이 만들었다는 사실을 배웠을 때처럼 경외심이 들면서도 "나는 저렇게 못해"라고 할까요, [고대 수메르 점토판의 영수증](https://www.lawtimes.co.kr/opinion/198116)을 보았을 때처럼 "옛날 사람들도 우리와 비슷하게 살았구나"하고 친숙함을 느낄까요.

> I suspect that, as my child comes of age, we will think of “the programmer” the way we now look back on “the computer,” when that phrase referred to a person who did calculations by hand. Programming by typing C++ or Python yourself might eventually seem as ridiculous as issuing instructions in binary onto a punch card. Dijkstra would be appalled, but getting computers to do precisely what you want might become a matter of asking politely.

인공지능이 과연 인간을 대체할 것인가 하는 주제에 대해 (1) 아직은 인간만이 할 수 있는 일이 있다 / 인공지능의 작업 품질이 만족스럽지 못하다 (2) 인공지능을 잘 활용하는 소수의 고효율 인력만 남고 나머지가 대체된다 / 지금처럼 많은 사람은 필요 없다 이렇게 두 가지 의견이 자주 보였는데요, 오늘 세 번째 답안을 [해커뉴스 댓글](https://news.ycombinator.com/item?id=38261948)에서 발견했습니다. (3) 개발자가 인공지능을 활용해 세 배 효율적이 된다면 할 일이 세 배로 늘어날 것이라고. 인공지능도 쓰고 사람도 쓰는 기업이 앞서나갈 것이고 경쟁에 따라가려면 모두 활용할 것이기 때문이라고.

> Something to remember is that every new innovation in software development only raises the expectations of the people paying the software developers. 
>
> If developers are 3x as productive, then the goals and features will be 3x big.
>
> The reason for this is that companies are in competition, if they lag behind, then others will eat up the market.
>
> The company that fires 50% of their staff because of “AI Assistance” is not going to be able to compete with the company that doesn’t fire their staff and still uses “AI Assistance”…

[대댓글](https://news.ycombinator.com/item?id=38262212)에서 재밌는 경제학 용어도 배웠습니다. [제본스의 역설 (Jevons Paradox)](https://ko.wikipedia.org/wiki/%EC%A0%9C%EB%B3%B8%EC%8A%A4%EC%9D%98_%EC%97%AD%EC%84%A4). 자원 효율이 좋아지면 자원을 아낄 것 같지만, 실제로는 단위비용이 감소하므로 수요가 늘어서 총 자원 소비가 늘어난다는 역설. 보통은 에너지 환경 분야에서 인용하는 논리인 듯 합니다. 그런데 인공지능과 개발자 수요에 대입해보면, 개발자의 효율(생산성)이 올라가면 역설적으로 자원(인공지능이건 개발자건)소비가 늘어난다는 이야기. 아직 세상에는 소프트웨어로 자동화할 일이 많이 있긴 하니까 수요가 늘어난다는 말도 일리 있어 보입니다. 관련해 인공지능과 에너지 환경에 대입한 이야기도 있네요 - [제본스의 역설: AI가 국가 전체만큼 많은 전기를 사용할 수 있다는 역설](https://ai.atsit.in/posts/2517389425/).

제본스의 역설대로 인공지능 발달이 프로그래머에게 더 많은 성과를 요구한다면, 인공지능을 활용해서 생산성을 적극적으로 늘려야만 하겠네요. 저자의 말대로 현재의 GPT가 풀 수 있는 단위로 문제를 분해하는 것, 즉 프로그래머들이 항상 하는 divide-and-conquer를 AI에도 적용해봐야겠습니다.

> 인공지능에게 “내 문제를 해결해줘”라고 말할 수는 없습니다. 언젠가 그런 날이 올지도 모르지만 지금은 연주법을 배워야 하는 악기와 비슷합니다. 초보자와 대화하듯 원하는 것을 신중하게 지정해야 합니다. 검색 강조 표시 문제에서 저는 GPT-4에 한 번에 너무 많은 작업을 요청하고 실패하는 것을 지켜본 다음 다시 시작하는 것을 발견했습니다. 그럴 때마다 제 프롬프트는 덜 야심적이었습니다. 대화가 끝날 무렵에는 검색이나 하이라이트에 관한 문제가 아니라 제가 원하는 것을 얻을 수 있는 구체적이고 추상적이며 모호하지 않은 하위 문제로 문제를 세분화했습니다.
>
> 인공지능의 수준을 발견한 순간, 제 업무 방식이 완전히 달라졌다는 것을 바로 느꼈습니다. 어디를 봐도 GPT-4 크기의 구멍이 보였고, 사무실의 화면이 항상 채팅 세션으로 가득 찬 이유와 벤의 생산성이 어떻게 그렇게 높아졌는지 마침내 이해하게 되었습니다. 저도 더 자주 시도해보고 싶다는 생각이 들었습니다.

혹 예상이 빗나가서 더 이상 인간 프로그래머가 필요하지 않게 된다면, 그땐 저를 프로그래머로 이끈 제 기질이 무엇이었는지 되돌아보고 제게 맞는 일을 또 찾아나서야 할지도 모르겠습니다. 아무렴 평생직업은 없는 시대니까요.

> 그래서 어쩌면 우리가 가르쳐야 할 것은 기술이 아니라 정신일지도 모릅니다. 저는 가끔 제가 다른 시대에 태어났다면 무엇을 하고 있었을지 생각해 봅니다. 가끔 제가 다른 시대에 태어났다면 무엇을 하고 있었을지 생각해 봅니다. 농경 시대의 코더들은 물레방아와 농작물 품종에 몰두했을 것이고, 뉴턴 시대에는 유리와 염료, 시간 측정에 집착했을지도 모릅니다.
