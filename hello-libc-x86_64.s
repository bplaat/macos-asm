; A simple pure assembly MACH-O x86_64 adhoc code signed dynamicly linked macOS executable with symbols
; nasm -f bin hello-libc-x86_64.s -o hello-libc-x86_64 && chmod +x hello-libc-x86_64 && codesign -s - hello-libc-x86_64 && ./hello-libc-x86_64

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

    %define VM_PROT_NONE 0x0
    %define VM_PROT_READ 0x1
    %define VM_PROT_WRITE 0x2
    %define VM_PROT_EXECUTE 0x4

    %define S_REGULAR 0x00000000
    %define S_ATTR_PURE_INSTRUCTIONS 0x80000000
    %define S_ATTR_SOME_INSTRUCTIONS 0x00000400

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
    dd 10                                 ; number of load commands
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
        dd 3                     ; number of symbols
        dd strings               ; string table offset
        dd strings_end - strings ; string table size
    symtab_end:

    dysymtab:
        dd LC_DYSYMTAB             ; command
        dd dysymtab_end - dysymtab ; command size
        times 2 dd 0               ; ?
        dd 0                       ; external symbols index
        dd 3                       ; external symbols size
        times 14 dd 0              ; ?
    dysymtab_end:

    load_dylinker:
        dd LC_LOAD_DYLINKER                  ; command
        dd load_dylinker_end - load_dylinker ; command size
        dd load_dylinker_str - load_dylinker ; string offset
    load_dylinker_str:
        db '/usr/lib/dyld', 0
        align 8, db 0
    load_dylinker_end:

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

    dyld_info:
        dd LC_DYLD_INFO_ONLY             ; command
        dd dyld_info_end - dyld_info     ; command size
        times 2 dd 0                     ; ?
        dd bindings - origin             ; bindings offset
        dd bindings_end - bindings       ; bindings size
        times 6 dd 0                     ; ?
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
    push rbp
    mov rbp, rsp

    lea rdi, [rel hello_string]
    call printf

    xor rdi, rdi
    call time
    mov rsi, rax
    lea rdi, [rel time_string]
    call printf

    xor eax, eax
    leave
    ret

printf: jmp [rel _printf]
time: jmp [rel _time]

text_end:
    align alignment, db 0
text_raw_end:

; Data section
data_start:
_printf dq 0
_time dq 0

hello_string db `Hello macOS from x86_64 assembly!\n`, 0
time_string db `It is now %ld seconds after UNIX epoch.\n`, 0

data_end:
    align alignment, db 0
data_raw_end:

; Linkedit section
linkedit_start:

bindings:
    db BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | 1 ; Select first loaded dylib
    db BIND_OPCODE_SET_TYPE_IMM | BIND_TYPE_POINTER

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_printf', 0
    db BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_time', 0
    db BIND_OPCODE_DO_BIND

    db BIND_OPCODE_DONE
    align 8, db 0
bindings_end:

; Symbols
symbols:
    dd L_start - strings ; string table offset
    db N_SECT | N_EXT    ; type flag
    db 1                 ; section number
    dw 0x0000            ; extra flags
    dq _start            ; address

    dd Lprintf - strings ; string table offset
    db N_SECT | N_EXT    ; type flag
    db 1                 ; section number
    dw 0x0000            ; extra flags
    dq printf            ; address

    dd Ltime - strings   ; string table offset
    db N_SECT | N_EXT    ; type flag
    db 1                 ; section number
    dw 0x0000            ; extra flags
    dq time              ; address
symbols_end:

strings:
    db 0
    L_start db '_start', 0
    Lprintf db 'printf', 0
    Ltime db 'time', 0
    align 8, db 0
strings_end:

linkedit_end:
    align alignment, db 0
linkedit_raw_end:
