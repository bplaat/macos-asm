; Hacky macro system to use some arm64 instruction in NASM because GAS sucks hard :)
; Written by Bastiaan van der Plaat (https://bplaat.nl/)

%define x0 0
%define x1 1
%define x2 2
%define x3 3
%define x4 4
%define x5 5
%define x6 6
%define x7 7
%define x8 8
%define x9 9
%define x10 10
%define x11 11
%define x12 12
%define x13 13
%define x14 14
%define x15 15
%define x16 16
%define x17 17
%define x18 18
%define x19 19
%define x20 20
%define x21 21
%define x22 22
%define x23 23
%define x24 24
%define x25 25
%define x26 26
%define x27 27
%define x28 28
%define fp 29
%define lr 30
%define sp 31

%macro arm64_mov 2
    dd 0xAA0003E0 | ((%2 & 31) << 16) | (%1 & 31))
%endmacro
%macro arm64_mov_imm 2
    dd 0xD2800000 | ((%2 & 0xffff) << 5) | (%1 & 31))
%endmacro
%macro arm64_ldr 2
    dd 0xF9400000 | ((%2 & 31) << 5) | (%1 & 31))
%endmacro
%macro arm64_str 2
    dd 0xF9000000 | ((%2 & 31) << 5) | (%1 & 31))
%endmacro
%macro arm64_adr 2
    dd 0x10000000 | ((((%2 - $) >> 2) << 5) | (%1 & 31))
%endmacro

%macro arm64_add 3
    dd 0x8B000000 | ((%3 & 31) << 16) | (%2 & 31) << 5) | (%1 & 31))
%endmacro
%macro arm64_add_imm 3
    dd 0x91000000 | (((%3 & 0x1fff) << 10) | (%2 & 31) << 5) | (%1 & 31))
%endmacro
%macro arm64_sub 3
    dd 0xCB000000 | ((%3 & 31) << 16) | (%2 & 31) << 5) | (%1 & 31))
%endmacro
%macro arm64_sub_imm 3
    dd 0xD1000000 | (((%3 & 0x1fff) << 10) | (%2 & 31) << 5) | (%1 & 31))
%endmacro

%macro arm64_cbz 2
    dd 0xB4000000 | (((((%2 - $) >> 2) & 0x7ffff) << 5) | (%1 & 31))
%endmacro
%macro arm64_cbnz 2
    dd 0xB5000000 | (((((%2 - $) >> 2) & 0x7ffff) << 5) | (%1 & 31))
%endmacro
%macro arm64_b 1
    dd 0x14000000 | (((%1 - $) >> 2) & 0x7ffffff)
%endmacro
%macro arm64_bl 1
    dd 0x94000000 | (((%1 - $) >> 2) & 0x7ffffff)
%endmacro
%macro arm64_blr 1
    dd 0xD63F0000 | ((%1 & 31) << 5)
%endmacro
%macro arm64_ret 0
    dd 0xD65F03C0
%endmacro
%macro arm64_svc 1
    dd 0xD4000001 | ((%1 & 0xffff) << 5)
%endmacro
