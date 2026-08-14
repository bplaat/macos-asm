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
; - linux x86_64, arm64
;
; Build instructions:
; - build: ./build-portable.py hello.s
; - windows: ./hello.com
; - unix: sh ./hello.com

%include 'libportable.s'
%include 'libarm64.s'

header HEADER_X86_64 | HEADER_ARM64

section_text

; Windows code
_windows_start:
    lea rax, qword [rel windows_print]
    mov qword [rel print], rax
    lea rax, qword [rel ExitProcess]
    mov qword [rel exit], rax
    jmp _start

windows_print:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rbp - 8], rdi
    mov r9, 0 ; NULL
    mov rcx, 0 ; NULL
    mov rdi, qword [rbp - 8]
    call strlen
    mov rdx, rax
    mov rsi, qword [rbp - 8]
    mov rdi, -11 ; STD_OUTPUT_HANDLE
    call GetStdHandle
    mov rdi, rax
    call WriteConsoleA
    leave
    ret

ms_abi_stub ExitProcess, 1
ms_abi_stub GetStdHandle, 1
ms_abi_stub WriteConsoleA, 5

; macOS code
_macos_start:
    lea rax, qword [rel macos_print]
    mov qword [rel print], rax
    lea rax, qword [rel macos_exit]
    mov qword [rel exit], rax
    jmp _start

macos_print:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rbp - 8], rdi
    call strlen
    mov rdx, rax
    mov rsi, qword [rbp - 8]
    mov edi, 1 ; stdout
    mov eax, 0x2000004 ; write
    syscall
    leave
    ret

macos_exit:
    mov eax, 0x2000001 ; exit
    syscall

; Linux code
_linux_start:
    lea rax, qword [rel linux_print]
    mov qword [rel print], rax
    lea rax, qword [rel linux_exit]
    mov qword [rel exit], rax
    jmp _start

linux_print:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rbp - 8], rdi
    call strlen
    mov rdx, rax
    mov rsi, qword [rbp - 8]
    mov edi, 1 ; stdout
    mov eax, 1 ; write
    syscall
    leave
    ret

linux_exit:
    mov eax, 60 ; exit
    syscall

; Shared code
_start:
    lea rdi, [rel message]
    call println

    xor edi, edi
    jmp [rel exit]

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

; ########################################################################################

align 4, db 0

; macOS code
_arm64_macos_start:
    arm64_adr x0, arm64_macos_print
    arm64_adr x1, print
    arm64_str x0, x1
    arm64_adr x0, arm64_macos_exit
    arm64_adr x1, exit
    arm64_str x0, x1
    arm64_b _arm64_start

arm64_macos_print:
    arm64_stp_pre fp, lr, sp, -32
    arm64_str_imm x0, sp, 24
    arm64_bl arm64_strlen
    arm64_mov x2, x0
    arm64_ldr_imm x1, sp, 24
    arm64_mov_imm x0, 1 ; stdout
    arm64_mov_imm x16, 4 ; write
    arm64_svc 0x80
    arm64_ldp_post fp, lr, sp, 32
    arm64_ret

arm64_macos_exit:
    arm64_mov_imm x16, 1 ; exit
    arm64_svc 0x80

; Linux code
_arm64_linux_start:
    arm64_adr x0, arm64_linux_print
    arm64_adr x1, print
    arm64_str x0, x1
    arm64_adr x0, arm64_linux_exit
    arm64_adr x1, exit
    arm64_str x0, x1
    arm64_b _arm64_start

arm64_linux_print:
    arm64_stp_pre fp, lr, sp, -32
    arm64_str_imm x0, sp, 24
    arm64_bl arm64_strlen
    arm64_mov x2, x0
    arm64_ldr_imm x1, sp, 24
    arm64_mov_imm x0, 1 ; stdout
    arm64_mov_imm x8, 64 ; write
    arm64_svc 0x0
    arm64_ldp_post fp, lr, sp, 32
    arm64_ret

arm64_linux_exit:
    arm64_mov_imm x8, 93 ; exit
    arm64_svc 0x0

; Shared code
_arm64_start:
    arm64_adr x0, message
    arm64_bl arm64_println

    arm64_mov_imm x0, 0
    arm64_adr x8, exit
    arm64_ldr x8, x8
    arm64_blr x8

arm64_strlen:
    arm64_mov x1, x0
.repeat:
    arm64_ldrb_post x2, x1, 1
    arm64_cbnz x2, .repeat
    arm64_sub x0, x1, x0
    arm64_sub_imm x0, x0, 1
    arm64_ret

arm64_println:
    arm64_str_pre lr, sp, -16

    arm64_adr x8, print
    arm64_ldr x8, x8
    arm64_blr x8

    arm64_adr x0, newline
    arm64_adr x8, print
    arm64_ldr x8, x8
    arm64_blr x8

    arm64_ldr_post lr, sp, 16
    arm64_ret

end_section_text

; ########################################################################################

section_data

print dq 0
exit dq 0

message db `Hello World!`, 0
align 4, db 0
newline db `\n`, 0
align 4, db 0

pe_import_table
    pe_library kernel32_table, 'KERNEL32.dll'

    pe_import kernel32_table, \
        ExitProcess, 'ExitProcess', \
        GetStdHandle, 'GetStdHandle', \
        WriteConsoleA, 'WriteConsoleA'
end_pe_import_table

end_section_data

footer
