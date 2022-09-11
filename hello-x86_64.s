; A simple pure assembly macho-o x86_64 dynamicly linked executable with symbols for macOS
; nasm -f bin hello-x86_64.s -o hello-x86_64 && chmod +x hello-x86_64 && ./hello-x86_64

    origin equ 0x100000000
    alignment equ 0x1000

    bits 64
    org origin

    %define MH_MAGIC_64 0xfeedfacf
    %define MH_EXECUTE 2
    %define MH_NOUNDEFS 0x0000001
    %define MH_DYLDLINK 0x0000004
    %define MH_PIE 0x0020000
    %define CPU_TYPE_X86_64 0x01000007
    %define CPU_SUBTYPE_X86_64_ALL 0x00000003

    %define LC_REQ_DYLD 0x80000000
    %define LC_SEGMENT_64 0x19
    %define LC_SYMTAB 0x02
    %define LC_DYSYMTAB 0x0b
    %define LC_LOAD_DYLINKER 0xe
    %define LC_LOAD_DYLIB 0xc
    %define LC_MAIN (0x28 | LC_REQ_DYLD)

    %define VM_PROT_NONE 0x0
    %define VM_PROT_READ 0x1
    %define VM_PROT_WRITE 0x2
    %define VM_PROT_EXECUTE 0x4

    %define S_REGULAR 0x00000000
    %define S_ATTR_PURE_INSTRUCTIONS 0x80000000
    %define S_ATTR_SOME_INSTRUCTIONS 0x00000400
    %define x86_THREAD_STATE64 0x4

    %define	N_EXT 0x01
    %define	N_SECT 0xe

    %define sys_exit 0x2000001
    %define sys_write 0x2000004
    %define stdout 1

; Macho Header
macho_header:
    dd MH_MAGIC_64                        ; magic
    dd CPU_TYPE_X86_64                    ; cpu type
    dd CPU_SUBTYPE_X86_64_ALL             ; cpu subtype
    dd MH_EXECUTE                         ; file type
    dd 8                                  ; number of load commands
    dd commands_end - commands            ; size of load commands
    dd MH_NOUNDEFS | MH_DYLDLINK | MH_PIE ; flags
    dd 0                                  ; reserved

; Macho load commands
commands:
    page_zero:
        dd LC_SEGMENT_64              ; command
        dd page_zero_end - page_zero  ; command size
        db "__PAGEZERO", 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                          ; vm address
        dq origin                     ; vm size
        dq 0                          ; file offset
        dq 0                          ; file size
        dd VM_PROT_NONE               ; maximum protection
        dd VM_PROT_NONE               ; inital protection
        dd 0                          ; number of sections
        dd 0x0                        ; flags
    page_zero_end:

    text_section:
        dd LC_SEGMENT_64                   ; command
        dd text_section_end - text_section ; command size
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq origin                          ; vm address
        dq text_raw_end - origin           ; vm size
        dq 0                               ; file offset
        dq text_raw_end - origin           ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; initial protection
        dd 1                               ; number of sections
        dd 0x0                             ; flags

        db "__text", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq text_start             ; address
        dq text_end - text_start  ; size
        dd text_start - origin    ; offset
        dd 2                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    text_section_end:

    data_section:
        dd LC_SEGMENT_64                   ; command
        dd data_section_end - data_section ; command size
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq data_start                      ; vm address
        dq data_raw_end - data_start       ; vm size
        dq data_start - origin             ; file offset
        dq data_raw_end - data_start       ; file size
        dd VM_PROT_READ | VM_PROT_WRITE    ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE    ; initial protection
        dd 1                               ; number of sections
        dd 0x0                             ; flags

        db "__data", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq data_start             ; address
        dq data_end - data_start  ; size
        dd data_start - origin    ; offset
        dd 0                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR              ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    data_section_end:

    symtab:
        dd LC_SYMTAB             ; command
        dd symtab_end - symtab   ; command size
        dd symbols               ; symbol table offset
        dd 2                     ; number of symbols
        dd strings               ; string table offset
        dd strings_end - strings ; string table size
    symtab_end:

    dysymtab:
        dd LC_DYSYMTAB ; command
        dd dysymtab_end - dysymtab ; command size
        times 2 dd 0 ; ?
        dd 0 ; external symbols index
        dd 2 ; external symbols size
        times 14 dd 0 ; ?
    dysymtab_end:

    load_dylinker:
        dd LC_LOAD_DYLINKER                  ; command
        dd load_dylinker_end - load_dylinker ; command size
        dd load_dylinker_str - load_dylinker ; string offet
    load_dylinker_str:
        db '/usr/lib/dyld'
        align 8, db 0
    load_dylinker_end:

    main:
        dd LC_MAIN         ; command
        dd main_end - main ; command size
        dq _start - origin ; entry point offset
        dq 0               ; init stack size
    main_end:

    load_libsystem:
        dd LC_LOAD_DYLIB                       ; command
        dd load_libsystem_end - load_libsystem ; command size
        dd load_libsystem_str - load_libsystem ; string offset
        dd 0                                   ; timestamp
        dw 0, 1                                ; current version
        dw 0, 1                                ; compatibility version
    load_libsystem_str:
        db '/usr/lib/libSystem.B.dylib'
        align 8, db 0
    load_libsystem_end:
commands_end:

; Text section
text_start:

_start:
    lea rdi, [rel hello]
    call strlen

    mov edx, eax
    lea rsi, [rel hello]
    mov edi, stdout
    mov eax, sys_write
    syscall

    xor edi, edi
    mov eax, sys_exit
    syscall

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

text_end:
    align alignment, db 0
text_raw_end:

; Data section
data_start:

hello: db "Hello macOS from x86_64 assembly!", 10, 0

data_end:
    align alignment, db 0
data_raw_end:

symbols:
    dd L_start - strings ; string table offset
    db N_SECT | N_EXT    ; type flag
    db 1                 ; section number
    dw 0x0000            ; extra flags
    dq _start            ; address

    dd L_strlen - strings ; string table offset
    db N_SECT | N_EXT     ; type flag
    db 1                  ; section number
    dw 0x0000             ; extra flags
    dq strlen             ; address
symbols_end:

strings:
    db 0
    L_start: db '_start', 0
    L_strlen: db 'strlen', 0
    align 8, db 0
strings_end:

    align alignment, db 0
