; This is a example of how you can call Objective-C Cocoa API's in Assembly and
; bundle the executable to an App Bundle which you can run and distribute easy!
    origin equ 0x100000000
    alignment equ 0x1000

    bits 64
    org origin

    %define MH_MAGIC_64 0xfeedfacf
    %define MH_EXECUTE 2
    %define MH_NOUNDEFS 0x00000001
    %define MH_DYLDLINK 0x00000004
    %define MH_PIE 0x00200000
    %define CPU_TYPE_X86_64 0x01000007
    %define CPU_SUBTYPE_X86_64_ALL 0x00000003

    %define LC_REQ_DYLD 0x80000000
    %define LC_SEGMENT_64 0x19
    %define LC_SYMTAB 0x02
    %define LC_DYSYMTAB 0x0b
    %define LC_LOAD_DYLINKER 0xe
    %define LC_LOAD_DYLIB 0xc
    %define LC_DYLD_INFO_ONLY (0x22 | LC_REQ_DYLD)
    %define LC_MAIN (0x28 | LC_REQ_DYLD)
    %define LC_BUILD_VERSION 0x32

    %define VM_PROT_NONE 0x0
    %define VM_PROT_READ 0x1
    %define VM_PROT_WRITE 0x2
    %define VM_PROT_EXECUTE 0x4

    %define S_REGULAR 0x00000000
    %define S_ATTR_PURE_INSTRUCTIONS 0x80000000
    %define S_ATTR_SOME_INSTRUCTIONS 0x00000400

    %define PLATFORM_MACOS 1
    %define TOOL_LD 1

    %define BIND_TYPE_POINTER 1
    %define BIND_OPCODE_SET_DYLIB_ORDINAL_IMM 0x10
    %define BIND_OPCODE_SET_TYPE_IMM 0x50
    %define BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM 0x40
    %define BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB 0x72
    %define BIND_OPCODE_DO_BIND 0x90
    %define BIND_OPCODE_DONE 0

    %define	N_EXT 0x01
    %define	N_SECT 0xe

; Macho Header
macho_header:
    dd MH_MAGIC_64                        ; magic
    dd CPU_TYPE_X86_64                    ; cpu type
    dd CPU_SUBTYPE_X86_64_ALL             ; cpu subtype
    dd MH_EXECUTE                         ; file type
    dd 13                                 ; number of load commands
    dd commands_end - commands            ; size of load commands
    dd MH_NOUNDEFS | MH_DYLDLINK | MH_PIE ; flags
    dd 0                                  ; reserved

; Macho load commands
commands:
    page_zero:
        dd LC_SEGMENT_64                  ; command
        dd page_zero_end - page_zero      ; command size
        db "__PAGEZERO", 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                              ; vm address
        dq origin                         ; vm size
        dq 0                              ; file offset
        dq 0                              ; file size
        dd VM_PROT_NONE                   ; maximum protection
        dd VM_PROT_NONE                   ; inital protection
        dd 0                              ; number of sections
        dd 0x0                            ; flags
    page_zero_end:

    text_section:
        dd LC_SEGMENT_64                          ; command
        dd text_section_end - text_section        ; command size
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq origin                                 ; vm address
        dq text_raw_end - origin                  ; vm size
        dq 0                                      ; file offset
        dq text_raw_end - origin                  ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE         ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE         ; initial protection
        dd 1                                      ; number of sections
        dd 0x0                                    ; flags

        db "__text", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq text_start                             ; address
        dq text_end - text_start                  ; size
        dd text_start - origin                    ; offset
        dd 2                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        dd 0                                      ; reserved1
        dd 0                                      ; reserved2
        dd 0                                      ; reserved3
    text_section_end:

    data_section:
        dd LC_SEGMENT_64                          ; command
        dd data_section_end - data_section        ; command size
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq data_start                             ; vm address
        dq data_raw_end - data_start              ; vm size
        dq data_start - origin                    ; file offset
        dq data_raw_end - data_start              ; file size
        dd VM_PROT_READ | VM_PROT_WRITE           ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE           ; initial protection
        dd 1                                      ; number of sections
        dd 0x0                                    ; flags

        db "__data", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq data_start                             ; address
        dq data_end - data_start                  ; size
        dd data_start - origin                    ; offset
        dd 0                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR                              ; flags
        dd 0                                      ; reserved1
        dd 0                                      ; reserved2
        dd 0                                      ; reserved3
    data_section_end:

    linkedit_section:
        dd LC_SEGMENT_64                           ; command
        dd linkedit_section_end - linkedit_section ; command size
        db "__LINKEDIT", 0, 0, 0, 0, 0, 0          ; segment name
        dq linkedit_start                          ; vm address
        dq linkedit_raw_end - linkedit_start       ; vm size
        dq linkedit_start - origin                 ; file offset
        dq linkedit_raw_end - linkedit_start       ; file size
        dd VM_PROT_READ                            ; maximum protection
        dd VM_PROT_READ                            ; initial protection
        dd 0                                       ; number of sections
        dd 0x0                                     ; flags
    linkedit_section_end:

    symtab:
        dd LC_SYMTAB             ; command
        dd symtab_end - symtab   ; command size
        dd symbols               ; symbol table offset
        dd 4                     ; number of symbols
        dd strings               ; string table offset
        dd strings_end - strings ; string table size
    symtab_end:

    dysymtab:
        dd LC_DYSYMTAB             ; command
        dd dysymtab_end - dysymtab ; command size
        times 2 dd 0               ; ?
        dd 0                       ; external symbols index
        dd 4                       ; external symbols size
        times 14 dd 0              ; ?
    dysymtab_end:

    build_version:
        dd LC_BUILD_VERSION                  ; command
        dd build_version_end - build_version ; command size
        dd PLATFORM_MACOS                    ; platform
        dw 0, 11                             ; minos
        dw 0, 14                             ; sdk
        dd 1                                 ; ntools
        dd TOOL_LD                           ; tool type
        dw 0, 1                              ; tool version
    build_version_end:

    load_dylinker:
        dd LC_LOAD_DYLINKER                  ; command
        dd load_dylinker_end - load_dylinker ; command size
        dd load_dylinker_str - load_dylinker ; string offset
    load_dylinker_str:
        db '/usr/lib/dyld', 0
        align 8, db 0
    load_dylinker_end:

    load_cocoa:
        dd LC_LOAD_DYLIB                       ; command
        dd load_cocoa_end - load_cocoa         ; command size
        dd load_cocoa_str - load_cocoa         ; string offset
        dd 0                                   ; timestamp
        dw 0, 1                                ; current version
        dw 0, 1                                ; compatibility version
    load_cocoa_str:
        db '/System/Library/Frameworks/Cocoa.Framework/Versions/A/Cocoa', 0
        align 8, db 0
    load_cocoa_end:

    load_libsystem:
        dd LC_LOAD_DYLIB                       ; command
        dd load_libsystem_end - load_libsystem ; command size
        dd load_libsystem_str - load_libsystem ; string offset
        dd 0                                   ; timestamp
        dw 0, 1                                ; current version
        dw 0, 1                                ; compatibility version
    load_libsystem_str:
        db '/usr/lib/libSystem.B.dylib', 0
        align 8, db 0
    load_libsystem_end:

    load_libobjc:
        dd LC_LOAD_DYLIB                       ; command
        dd load_libobjc_end - load_libobjc     ; command size
        dd load_libobjc_str - load_libobjc     ; string offset
        dd 0                                   ; timestamp
        dw 0, 1                                ; current version
        dw 0, 1                                ; compatibility version
    load_libobjc_str:
        db '/usr/lib/libobjc.A.dylib', 0
        align 8, db 0
    load_libobjc_end:

    dyld_info:
        dd LC_DYLD_INFO_ONLY             ; command
        dd dyld_info_end - dyld_info     ; command size
        times 2 dd 0
        dd bindings - origin             ; bindings offset
        dd bindings_end - bindings       ; bindings size
        times 6 dd 0
    dyld_info_end:

    main:
        dd LC_MAIN         ; command
        dd main_end - main ; command size
        dq _start - origin ; entry point offset
        dq 0               ; init stack size
    main_end:
commands_end:

    align 256, db 0

; Text section
text_start:

_start:
    ; id alert;
    ; id message;
    push rbp
    mov rbp, rsp
    sub rsp, 16
    %define alert qword [rbp - 8]
    %define message qword [rbp - 16]

    ; tmp = sel_registerName("new");
    lea rdi, [rel new]
    call sel_registerName
    push rax
    ; alert = objc_msgSend(objc_getClass("NSAlert"), tmp);
    lea rdi, [rel NSAlert]
    call objc_getClass
    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov alert, rax

    ; tmp = sel_registerName("stringWithUTF8String:")
    lea rdi, [rel stringWithUTF8String]
    call sel_registerName
    push rax
    ; message = objc_msgSend(objc_getClass("NSString"), tmp, "Hello Cocoa from x86_64 assembly");
    lea rdi, [rel NSString]
    call objc_getClass
    lea rdx, [rel hello_string]
    pop rsi
    mov rdi, rax
    call objc_msgSend
    mov message, rax

    ; objc_msgSend(alert, sel_registerName("setMessageText:"), message);
    lea rdi, [rel setMessageText]
    call sel_registerName
    mov rdx, message
    mov rsi, rax
    mov rdi, alert
    call objc_msgSend

    ; objc_msgSend(alert, sel_registerName("runModal:"));
    lea rdi, [rel runModal]
    call sel_registerName
    mov rsi, rax
    mov rdi, alert
    call objc_msgSend

    ; return 0;
    xor eax, eax
    leave
    ret

objc_getClass: jmp [rel _objc_getClass]
objc_msgSend: jmp [rel _objc_msgSend]
sel_registerName: jmp [rel _sel_registerName]

text_end:
    align alignment, db 0
text_raw_end:

; Data section
data_start:
_objc_getClass dq 0
_objc_msgSend dq 0
_sel_registerName dq 0

NSAlert db 'NSAlert', 0
new db 'new', 0
NSString db 'NSString', 0
stringWithUTF8String db 'stringWithUTF8String:', 0
setMessageText db 'setMessageText:', 0
runModal db 'runModal', 0

hello_string db 'Hello Cocoa from x86_64 assembly!', 0

data_end:
    align alignment, db 0
data_raw_end:

; Linkedit section
linkedit_start:

bindings:
    db BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | 3 ; Select libobjc loaded dylib
    db BIND_OPCODE_SET_TYPE_IMM | BIND_TYPE_POINTER

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_objc_getClass', 0
    db BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_objc_msgSend', 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_sel_registerName', 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_DONE
bindings_end:
    align 8, db 0

; Symbols
%macro symbol 1
    dd L%1 - strings  ; string table offset
    db N_SECT | N_EXT ; type flag
    db 1              ; section number
    dw 0x0000         ; extra flags
    dq %1             ; address
%endmacro
symbols:
    symbol _start
    symbol objc_getClass
    symbol objc_msgSend
    symbol sel_registerName
symbols_end:
strings:
    L_start db '_start', 0
    Lobjc_getClass db 'objc_getClass', 0
    Lobjc_msgSend db 'objc_msgSend', 0
    Lsel_registerName db 'sel_registerName', 0
strings_end:
    align 8, db 0

linkedit_end:
    align alignment, db 0
linkedit_raw_end:
