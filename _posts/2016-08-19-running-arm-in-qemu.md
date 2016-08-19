---
layout: post
title: Running ARM in QEMU
category: dev
---

QEMU에서 ARM debian을 돌리는 방법 정리.

<https://www.aurel32.net/info/debian_arm_qemu.php> 와
<https://people.debian.org/~aurel32/qemu/armhf/>를 참고하면 쉽게 할 수 있다.

## 1. Install

먼저 qemu를 설치한다.

```
sudo apt-get install qemu
```

그 다음 이미지들을 다운받는다.

```
wget https://people.debian.org/~aurel32/qemu/armhf/debian_wheezy_armhf_standard.qcow2
wget https://people.debian.org/~aurel32/qemu/armhf/initrd.img-3.2.0-4-vexpress
wget https://people.debian.org/~aurel32/qemu/armhf/vmlinuz-3.2.0-4-vexpress
```

- `debian_wheezy_armhf_standard.qcow2`는 debian wheezy가 설치된 디스크 이미지,
- `initrd.img-3.2.0-4-vexpress`는 부팅에 필요한 임시 파일시스템 (initrd; initial ramdisk) 이미지,
- `vmlinuz-3.2.0-4-vexpress`는 리눅스 커널 이미지이다.

이 중에서 qcow2 이미지는 시스템을 사용하면 내용이 바뀌기 때문에 (디스크 이미지니까) 깨끗한 버전을 하나 백업해 두는 것도 좋은 생각이다.

## 2. Basic run

부팅에 필요한 최소한의 옵션은 아래와 같다.

```
qemu-system-arm -M vexpress-a9 \
    -kernel vmlinuz-3.2.0-4-vexpress \
    -initrd initrd.img-3.2.0-4-vexpress \
    -drive if=sd,file=debian_wheezy_armhf_standard.qcow2 \
    -append "root=/dev/mmcblk0p2"
```

이러면 qemu 창이 뜨고 debian이 부팅된다. 부팅이 끝나면 root/root로 로그인하면 된다.
부팅은 노트북에서 1~3분정도 걸리는 것 같다. 끌 때는 root로 로그인해서 `poweroff`해주면 된다.

각 옵션을 설명하자면 다음과 같다.

- `-M vexpress-a9` 다운받은 커널과 initrd가 vexpress보드에 맞춰져 있기 때문에 (파일명을 보면 알 수 있다) vexpress를 에뮬레이션해야 한다.
- `-kernel, -initrd` 커널 이미지와 initrd 이미지를 세팅한다.
- `-drive if=sd,file=debian_wheezy_armhf_standard.qcow2` SD카드 슬롯에 debian 이미지를 넣는다.
- `-append "root=/dev/mmcblk0p2"` 부팅 시 커널 command line option을 추가하는 부분인데, root file system을 SD카드인 `/dev/mmcblk0p2`로 한다는 뜻이다.

## 3. CUI 환경에서 사용

창이 안 뜨는 terminal이나 ssh환경에서는 다음과 같이 하면 된다.

```
qemu-system-arm -M vexpress-a9 \
    -kernel vmlinuz-3.2.0-4-vexpress \
    -initrd initrd.img-3.2.0-4-vexpress \
    -drive if=sd,file=debian_wheezy_armhf_standard.qcow2 \
    -append "root=/dev/mmcblk0p2 console=ttyAMA0" \
    -nographic
```

`console=ttyAMA0`은 콘솔 입출력을 시리얼 포트를 통해 하라는 뜻이고
`-nographic`은 GUI창을 띄우지 않겠다는 뜻이다.

이러면 부팅 메시지부터 쉘까지 모두 터미널 상에서 해결된다.

## 4. 인터넷 사용

TCP redirection 옵션을 추가하면 된다.

```
qemu-system-arm -M vexpress-a9 \
    -kernel vmlinuz-3.2.0-4-vexpress \
    -initrd initrd.img-3.2.0-4-vexpress \
    -drive if=sd,file=debian_wheezy_armhf_standard.qcow2 \
    -append "root=/dev/mmcblk0p2 console=ttyAMA0" \
    -redir tcp:10022::22 -redir tcp:10080::80
    -nographic
```

이러면 host 10022번과 10080번이 각각 guest 22번과 80번으로 연결된다.

