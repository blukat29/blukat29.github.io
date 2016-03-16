---
layout: post
title: 성질 급한 사람을 위한 LaTeX
category: Uncategorized
---

LaTex 입문서로는 [142분 동안 익히는 LaTeX 2e](http://texdoc.net/texmf-dist/doc/latex/lshort-korean/lshort-kr.pdf) 라는 좋은 한국어 문서가 있으나, 나처럼 성질 급한 사람을 위해 이 글을 쓴다.

## 1. 설치하기 (Mac OS X)

1. 권장하는 방법은 MacTex를 설치하는 것이지만 MacTex는 용량이 너무 커서 오래걸리니 BasicTex를 다운받는다. 링크: <http://tug.org/cgi-bin/mactex-download/BasicTeX.pkg>
2. 다운받은 pkg파일을 더블클릭하여 설치를 완료한다.

## 2. 설치하기 (Ubuntu)

```
sudo apt-get install texlive
```

## 3. 사용하기

다음 파일을 `hello.tex`로 저장한다.

```tex
\documentclass{article}
\begin{document}
hello
\end{document}
```

다음을 실행한다.

```
pdflatex hello.tex
```

그려면 `hello.pdf`가 생성된다.

