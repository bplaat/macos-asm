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
%define x16 16

%macro arm64_mov 2
    dd 0xAA0003E0 | ((%2 & 31) << 16) | (%1 & 31))
%endmacro
%macro arm64_mov_imm 2
    dd 0xD2800000 | ((%2 & 0xffff) << 5) | (%1 & 31))
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
%macro arm64_adr 2
    dd 0x10000000 | ((((%2 - $) >> 2) << 5) | (%1 & 31))
%endmacro
%macro arm64_cbz 2
    dd 0xB4000000 | (((((%2 - $) >> 2) & 0x7ffff) << 5) | (%1 & 31))
%endmacro
%macro arm64_b 1
    dd 0x14000000 | (((%1 - $) >> 2) & 0x7ffffff)
%endmacro
%macro arm64_bl 1
    dd 0x94000000 | (((%1 - $) >> 2) & 0x7ffffff)
%endmacro
%macro arm64_ret 0
    dd 0xD65F03C0
%endmacro
%macro arm64_svc 1
    dd 0xD4000001 | ((%1 & 0xffff) << 5)
%endmacro
