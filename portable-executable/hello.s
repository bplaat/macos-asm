; A portable / multiplatform native executable example written in pure x86_64 assembler
; Written by Bastiaan van der Plaat (https://bplaat.nl/)
;
; The working is inspired by: https://justine.lol/ape.html
; It uses a self modifing shell script header to copy the right MACH-O or ELF header to the front of the file
; On Windows (and so also MS-DOS) the header is already present
; The program uses the System-V ABI so whe need stubs to call win32 functions
;
; Supports:
; - windows x86_64, MS-DOS (stub)
; - macos x86_64, arm64
; - linux x86_64
;
; Build instructions:
; - windows: nasm -f bin hello.s -o hello.com && ./hello.com
; - macos: nasm -f bin hello.s -o hello.com && chmod +x hello.com && sh ./hello.com
; - linux: nasm -f bin hello.s -o hello.com && chmod +x hello.com && ./hello.com
;
; TODO items:
; - A sections and so section names to the Linux header so that `objdump -S` works
; - Add linux arm64 support
; - Do macOS codesign without codesign command on first run

%include 'libportable.s'
%include 'libarm64.s'

header

section_text

; Windows code
_win32_start:
    lea rax, qword [rel win32_print]
    mov qword [rel print], rax
    lea rax, qword [rel win32_exit]
    mov qword [rel exit], rax
    jmp _start

win32_print:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov qword [rbp - 8], rdi

    mov r9, NULL
    mov rcx, NULL

    mov rdi, qword [rbp - 8]
    call strlen
    mov rdx, rax

    mov rsi, qword [rbp - 8]

    mov rdi, STD_OUTPUT_HANDLE
    call @GetStdHandle
    mov rdi, rax

    call @WriteConsoleA

    leave
    ret

win32_exit:
    jmp @ExitProcess

; macOS code
_macos_start:
    lea rax, qword [rel unix_print]
    mov qword [rel print], rax
    lea rax, qword [rel unix_exit]
    mov qword [rel exit], rax
    mov dword [rel sys_exit], 0x2000001
    mov dword [rel sys_write], 0x2000004
    jmp _start

; Linux code
_linux_start:
    lea rax, qword [rel unix_print]
    mov qword [rel print], rax
    lea rax, qword [rel unix_exit]
    mov qword [rel exit], rax
    mov dword [rel sys_exit], 60
    mov dword [rel sys_write], 1
    jmp _start

; Unix code
unix_print:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov qword [rbp - 8], rdi

    call strlen
    mov rdx, rax

    mov rsi, qword [rbp - 8]
    mov edi, stdout
    mov eax, dword [rel sys_write]
    syscall

    leave
    ret

unix_exit:
    mov eax, dword [rel sys_exit]
    syscall

; Shared code
_start:
    lea rdi, [rel message]
    call println

    xor edi, edi
    call [rel exit]

strlen:
    mov rax, rdi
.repeat:
    cmp byte [rax], 0
    je .done
    inc rax
    jmp .repeat
.done:
    sub rax, rdi
    ret

println:
    call [rel print]
    lea rdi, [rel newline]
    call [rel print]
    ret

; Win32 stubs
@ExitProcess:
    sub rsp, 32
    mov rcx, rdi
    jmp [rel ExitProcess]

@GetStdHandle:
    sub rsp, 32
    mov rcx, rdi
    call [rel GetStdHandle]
    add rsp, 32
    ret

@WriteConsoleA:
    sub rsp, 48
    mov qword [rsp + 4 * 8], r8
    mov r9, rcx
    mov r8, rdx
    mov rdx, rsi
    mov rcx, rdi
    call [rel WriteConsoleA]
    add rsp, 48
    ret

; ########################################################################################

align 4, db 0

_arm64_macos_start:
    arm64_adr x0, message
    arm64_bl arm64_strlen
    arm64_mov x2, x0
    arm64_adr x1, message
    arm64_mov_imm x0, stdout
    arm64_mov_imm x16, 4
    arm64_svc 0x80

    arm64_mov_imm x2, 1
    arm64_adr x1, newline
    arm64_mov_imm x0, stdout
    arm64_mov_imm x16, 4
    arm64_svc 0x80

    arm64_mov_imm x0, 0
    arm64_mov_imm x16, 1
    arm64_svc 0x80

arm64_strlen:
    arm64_mov x1, x0
.repeat:
    dd 0x39400022 ; ldrb w2, [x1]
    arm64_cbz x2, .done
    arm64_add_imm x1, x1, 1
    arm64_b .repeat
.done:
    arm64_sub x0, x1, x0
    arm64_ret

end_section_text

; ########################################################################################

section_data

print dq 0
exit dq 0
sys_exit dd 0
sys_write dd 0

align 4, db 0
message db `Hello World!`, 0
align 4, db 0
newline db `\n`, 0

_pe_import_table:
    dd 0, 0, 0, kernel32_name, kernel32_table
    dd 0, 0, 0, 0, 0

kernel32_table:
    ExitProcess dq _ExitProcess
    GetStdHandle dq _GetStdHandle
    WriteConsoleA dq _WriteConsoleA
    dq 0

    kernel32_name db 'KERNEL32.DLL', 0
    _ExitProcess db 0, 0, 'ExitProcess', 0
    _GetStdHandle db 0, 0, 'GetStdHandle', 0
    _WriteConsoleA db 0, 0, 'WriteConsoleA', 0

_pe_import_table_size equ $ - _pe_import_table

end_section_data

footer
