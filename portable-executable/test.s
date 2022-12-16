; Portable / multiplatform native executable
; Inspired by: https://justine.lol/ape.html
; - windows x86_64
; - macos x86_64 DONE
; - linux x86_64
; macOS: nasm -f bin test.s -o test && chmod +x test && ./test
; Windows: nasm -f bin test.s -o test && ./test

    %define MH_MAGIC_64 0xfeedfacf
    %define MH_EXECUTE 2
    %define MH_NOUNDEFS 0x0000001
    %define MH_PIE 0x00200000
    %define CPU_TYPE_X86_64 0x01000007
    %define CPU_SUBTYPE_X86_64_ALL 0x00000003

    %define LC_SEGMENT_64 0x19
    %define LC_UNIXTHREAD 0x05

    %define VM_PROT_NONE 0x0
    %define VM_PROT_READ 0x1
    %define VM_PROT_WRITE 0x2
    %define VM_PROT_EXECUTE 0x4

    %define S_REGULAR 0x00000000
    %define S_ATTR_PURE_INSTRUCTIONS 0x80000000
    %define S_ATTR_SOME_INSTRUCTIONS 0x00000400
    %define x86_THREAD_STATE64 0x4

    %define sys_exit 0x2000001
    %define sys_write 0x2000004
    %define stdout 1

%macro header 0
    _origin equ 0x100000000
    _alignment equ 0x1000

    bits 64

_ms_dos_header:
    db `MZ='\nhoi'\n`

_shell_script:
    db `if [ "$(uname -s)" = Darwin ]; then\n`
    db `dd if="$0" of="$0" bs=1 skip=256 count=4096 conv=notrunc 2> /dev/null\n`
    db `exec "$0" "$@"\n`
    db `else\n`
    db `echo "linux todo"\n`
    db `fi\n`
    db `exit 1\n`
    align 0x100, db 0

_macho_header:
    dd MH_MAGIC_64                           ; magic
    dd CPU_TYPE_X86_64                       ; cputype
    dd CPU_SUBTYPE_X86_64_ALL                ; cpusubtype
    dd MH_EXECUTE                            ; filetype
    dd 4                                     ; ncmds
    dd _macho_commands_end - _macho_commands ; sizeofcmds
    dd MH_NOUNDEFS | MH_PIE                  ; flags
    dd 0                                     ; reserved

_macho_commands:
    _command_page_zero:
        dd LC_SEGMENT_64                               ; cmd
        dd _command_page_zero_end - _command_page_zero ; cmdsize
        db "__PAGEZERO", 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                          ; vm address
        dq _origin                    ; vm size
        dq 0                          ; file offset
        dq 0                          ; file size
        dd VM_PROT_NONE               ; maximum protection
        dd VM_PROT_NONE               ; inital protection
        dd 0                          ; number of _sections
        dd 0x0                        ; flags
    _command_page_zero_end:

    _command_text_section:
        dd LC_SEGMENT_64                   ; command
        dd _command_text_section_end - _command_text_section ; command size
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _origin                         ; vm address
        dq _section_text_raw_end          ; vm size
        dq 0                               ; file offset
        dq _section_text_raw_end          ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; initial protection
        dd 1                               ; number of _sections
        dd 0x0                             ; flags

        db "__text", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _origin + _section_text             ; address
        dq _section_text_end - _section_text  ; size
        dd _section_text   ; offset
        dd 2                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    _command_text_section_end:

    _command_data_section:
        dd LC_SEGMENT_64                   ; command
        dd _command_data_section_end - _command_data_section ; command size
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _origin + _section_data                      ; vm address
        dq _section_data_raw_end - _section_data       ; vm size
        dq _section_data             ; file offset
        dq _section_data_raw_end - _section_data       ; file size
        dd VM_PROT_READ | VM_PROT_WRITE    ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE    ; initial protection
        dd 1                               ; number of _sections
        dd 0x0                             ; flags

        db "__data", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _origin + _section_data             ; address
        dq _section_data_end - _section_data  ; size
        dd _section_data                      ; offset
        dd 0                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR              ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    _command_data_section_end:

    _command_unix_thread:
        dd LC_UNIXTHREAD                                   ; cmd
        dd _command_unix_thread_end - _command_unix_thread ; cmdsize
        dd x86_THREAD_STATE64                              ; flavour
        dd 42                                              ; count
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0          ; regs
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0          ; ...
        dq _origin + _start, 0x0, 0x0, 0x0, 0x0            ; rip, ...
    _command_unix_thread_end:
_macho_commands_end:
    align _alignment, db 0
%endmacro

%macro section_text 0
_section_text:
%endmacro
%macro section_text_end 0
_section_text_end:
    align _alignment, db 0
_section_text_raw_end:
%endmacro
%macro section_data 0
_section_data:
%endmacro
%macro section_data_end 0
_section_data_end:
    align _alignment, db 0
_section_data_raw_end:
%endmacro

; ####################################################################

header

section_text

_start:
    lea rdi, [rel message]
    call println

    xor edi, edi
    call exit

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

print:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov qword [rbp - 8], rdi
    call strlen

    mov edx, eax
    mov rsi, qword [rbp - 8]
    mov edi, stdout
    mov eax, sys_write
    syscall

    leave
    ret

println:
    call print
    lea rdi, [rel newline]
    call print
    ret

exit:
    mov eax, sys_exit
    syscall

section_text_end

section_data

message db `Hello World!`, 0
newline db `\n`, 0

section_data_end
