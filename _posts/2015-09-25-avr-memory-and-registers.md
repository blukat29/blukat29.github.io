---
layout: post
title: AVR Memory and Registers
category: reversing
---

AVR은 Atmel사에서 개발한 8비트 RISC 마이크로프로세서다. x86이나 ARM에 비해 특이한 점들이 많아서 따로 정리한다.

### 1. 아키텍처

AVR은 Harvard Architecture ([참고](http://jsy6036.tistory.com/entry/%ED%8F%B0-%EB%85%B8%EC%9D%B4%EB%A7%8C-%EA%B5%AC%EC%A1%B0%EC%99%80-%ED%95%98%EB%B2%84%EB%93%9C-%EA%B5%AC%EC%A1%B0)) 로 되어있어서 프로그 램 메모리와 데이터 메모리가 분리되어 있다.

AVR의 메모리는 Flash memory, SRAM, EEPROM으로 구성되어 있고, 각자 memory space를 가진다.

- Flash memory: 프로그램 메모리.
- SRAM: 데이터 메모리.
- EEPROM: 데이터를 반 영구적으로 저장하기 위한 보조기억장치.

Flash memory와 SRAM은 둘 다 0부터 시작하는 16비트 address space를 가지고 있는데, 이를 ELF파일과 IDA에서는 프로그램이 0x0000부터 시작하고, 데이터가 0x800000부터 시작하는 것으로 표현하고 있다. 실제 주소가 0x800000가 아님에 주의해야 한다.

### 2. 레지스터

AVR에는 총 32개의 general purpose 레지스터가 있다. AVR에서는 레지스터가 memory-map되어 있어서 r0~r31는 메모리 0x00~0x1f에 위치한다.

- r27:r26을 붙이면 (r27이 high byte) X라는 16비트 레지스터가 된다.
- r29:r28은 Y인데, ebp처럼 stack frame pointer로 쓰인다.
- r31:r30은 Z라고도 부르는데, 프로그램 메모리를 읽어올 때 쓰인다.
- r1의 값은 항상 0이다.
- 함수의 argument는 순서대로 r25:r24, r23:r22, r21:r20, ... 을 통해 전달한다.
- 함수의 return value는 r25:r24에 저장한다.

AVR에는 SREG와 SP라는 special purpose 레지스터도 있다.

- SREG(Status Register)는 x86의 FLAGS와 비슷하게 sign flag, overflow flag, zero flag 등을 담고 있으며 연산을 할 때마다 자동으로 바뀐다.
- SP(Stack Pointer)는 x86의 esp와 같은 역할이다.
- SREG는 0x3F에, SP는 SPH:SPL이 0x3E:0x3D에 해당한다.

### 3. SRAM

AVR의 SRAM은 데이터를 읽고 쓰는 것 외에 레지스터 접근, memory-mapped I/O 등의 다양한 용도로 쓰인다.

- 0x00 ~ 0x1f: Registers r0 ~ r31
- 0x20 ~ 0x5f: I/O (SREG, SPL, SPH, ...)
- 0x60 ~ 0xff : Extended I/O (serial, UART, ...)
- 0x100 ~ : Data

### References

- Amtel AVR instruction set <https://en.wikipedia.org/wiki/Atmel_AVR_instruction_set>
- Amtel Assembly User Guide <http://www.atmel.com/Images/doc1022.pdf>
- Amtel AVR <https://en.wikipedia.org/wiki/Atmel_AVR>
- AVR Assembly 일람 <http://www.atmel.com/webdoc/avrassembler/avrassembler.wb_instruction_list.html>

