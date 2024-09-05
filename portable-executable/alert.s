; A portable native GUI alert program written in assembler
; Written by Bastiaan van der Plaat (https://bplaat.nl/)
;
; Supports:
; - windows x86_64
; - macos x86_64
; - FIXME: linux x86_64
;
; Build instructions:
; - windows: nasm -f bin alert.s -o alert.com && ./alert.com
; - unix: nasm -f bin alert.s -o alert.com && chmod +x alert.com && sh ./alert.com

%include 'libportable.s'

%define HWND_DESKTOP 0
%define MB_OK 0

%define NSApplicationActivationPolicyRegular 0
%define YES 1

%define macho_libraries_count 3
%macro macho_libraries 0
    macho_library cocoa, '/System/Library/Frameworks/Cocoa.Framework/Versions/A/Cocoa'
    macho_library libsystem, '/usr/lib/libSystem.B.dylib'
    macho_library libobjc, '/usr/lib/libobjc.A.dylib'
%endmacro
%macro macho_bindings 0
    db BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | 3
    db BIND_OPCODE_SET_TYPE_IMM | BIND_TYPE_POINTER

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_objc_getClass', 0
    db BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_objc_msgSend', 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_sel_registerName', 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_DONE
%endmacro

header HEADER_X86_64

; ########################################################################################

section_text

; Windows code
_windows_start:
    mov ecx, MB_OK
    lea rdx, [rel message_title]
    lea rsi, [rel message_text]
    mov edi, HWND_DESKTOP
    call MessageBoxA

    mov edi, 0
    call ExitProcess

ms_abi_stub ExitProcess, 1
ms_abi_stub MessageBoxA, 4

; ########################################################################################

; macOS Code
_macos_start:
    ; id app, alert, messageTitle, messageText;
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; app = objc_msgSend(objc_getClass("NSApplication"), sel_registerName("sharedApplication"));
    lea rdi, [rel sharedApplication]
    call sel_registerName
    push rax
    lea rdi, [rel NSApplication]
    call objc_getClass
    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov qword [rbp - 8], rax

    ; objc_msgSend(app, sel_registerName("setActivationPolicy:"), NSApplicationActivationPolicyRegular);
    lea rdi, [rel setActivationPolicy]
    call sel_registerName
    mov rdx, NSApplicationActivationPolicyRegular
    mov rsi, rax
    mov rdi, qword [rbp - 8]
    call objc_msgSend

    ; objc_msgSend(app, sel_registerName("activateIgnoringOtherApps:"), YES);
    lea rdi, [rel activateIgnoringOtherApps]
    call sel_registerName
    mov rdx, YES
    mov rsi, rax
    mov rdi, qword [rbp - 8]
    call objc_msgSend

    ; alert = objc_msgSend(objc_getClass("NSAlert"), sel_registerName("new"));
    lea rdi, [rel new]
    call sel_registerName
    push rax

    lea rdi, [rel NSAlert]
    call objc_getClass

    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov qword [rbp - 16], rax

    ; messageTitle = objc_msgSend(objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), "Hello Cocoa from x86_64 assembly");
    lea rdi, [rel stringWithUTF8String]
    call sel_registerName
    push rax
    lea rdi, [rel NSString]
    call objc_getClass
    lea rdx, [rel message_title]
    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov qword [rbp - 24], rax

    ; objc_msgSend(alert, sel_registerName("setMessageText:"), messageTitle);
    lea rdi, [rel setMessageText]
    call sel_registerName
    mov rdx, qword [rbp - 24]
    mov rsi, rax
    mov rdi, qword [rbp - 16]
    call objc_msgSend

    ; messageText = objc_msgSend(objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), "Hello Cocoa from x86_64 assembly");
    lea rdi, [rel stringWithUTF8String]
    call sel_registerName
    push rax
    lea rdi, [rel NSString]
    call objc_getClass
    lea rdx, [rel message_text]
    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov qword [rbp - 32], rax

    ; objc_msgSend(alert, sel_registerName("setInformativeText:"), messageText);
    lea rdi, [rel setInformativeText]
    call sel_registerName
    mov rdx, qword [rbp - 32]
    mov rsi, rax
    mov rdi, qword [rbp - 16]
    call objc_msgSend

    ; objc_msgSend(alert, sel_registerName("runModal:"));
    lea rdi, [rel runModal]
    call sel_registerName
    mov rsi, rax
    mov rdi, qword [rbp - 16]
    call objc_msgSend

    ; return 0;
    xor eax, eax
    leave
    ret

objc_getClass: jmp [rel _objc_getClass]
objc_msgSend: jmp [rel _objc_msgSend]
sel_registerName: jmp [rel _sel_registerName]

; ########################################################################################

; Linux code
_linux_start:
    ; FIXME: Add X11 implementation maybe?

    xor edi, edi
    mov eax, 60 ; exit
    syscall

end_section_text

; ########################################################################################

section_data

_objc_getClass dq 0
_objc_msgSend dq 0
_sel_registerName dq 0

NSApplication db 'NSApplication', 0
sharedApplication db 'sharedApplication', 0
setActivationPolicy db 'setActivationPolicy:', 0
activateIgnoringOtherApps db 'activateIgnoringOtherApps:', 0

NSAlert db 'NSAlert', 0
new db 'new', 0
NSString db 'NSString', 0
stringWithUTF8String db 'stringWithUTF8String:', 0
setMessageText db 'setMessageText:', 0
setInformativeText db 'setInformativeText:', 0
runModal db 'runModal', 0

message_title db 'Hello World!', 0
message_text db 'From a native GUI alert!', 0

pe_import_table
    pe_library kernel32_table, 'KERNEL32.dll', \
        user32_table, 'USER32.dll'

    pe_import kernel32_table, \
        ExitProcess, 'ExitProcess'

    pe_import user32_table, \
        MessageBoxA, 'MessageBoxA'
end_pe_import_table

end_section_data

footer
