; Portable / multiplatform native executable
; Inspired by: https://justine.lol/ape.html
; - windows x86_64 / MS-DOS DONE
; - macos x86_64 DONE
; - linux x86_64
; macOS: nasm -f bin test.s -o test && chmod +x test && ./test
; Windows: nasm -f bin test.s -o test.exe && ./test

    ; MACH-O consts
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

    ; Program consts
    %define STD_OUTPUT_HANDLE -11
    %define NULL 0
    %define stdout 1
    %define macos_sys_exit 0x2000001
    %define macos_sys_write 0x2000004

%macro header 0
    _macho_origin equ 0x0000000100000000
    _pe_origin equ 0x0000000000400000
    _alignment equ 0x1000

    bits 64

_header:

_ms_dos_header:
    db `MZ='\n`, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00
    db 0xB8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    dd _pe_header

_ms_dos_stub:
    db 0x0E, 0x1F, 0xBA, 0x0E, 0x00, 0xB4, 0x09, 0xCD, 0x21, 0xB8, 0x01, 0x4C, 0xCD, 0x21, 0x54, 0x68
    db 0x69, 0x73, 0x20, 0x70, 0x72, 0x6F, 0x67, 0x72, 0x61, 0x6D, 0x20, 0x63, 0x61, 0x6E, 0x6E, 0x6F
    db 0x74, 0x20, 0x62, 0x65, 0x20, 0x72, 0x75, 0x6E, 0x20, 0x69, 0x6E, 0x20, 0x44, 0x4F, 0x53, 0x20
    db 0x6D, 0x6F, 0x64, 0x65, 0x2E, 0x0D, 0x0D, 0x0A, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

_shell_script:
    db `\n'\n`
    db `if [ "$(uname -s)" = Darwin ]; then\n`
    db `dd if="$0" of="$0" bs=1 skip=512 count=4096 conv=notrunc 2> /dev/null\n`
    db `exec "$0" "$@"\n`
    db `else\n`
    db `echo "linux todo"\n`
    db `fi\n`
    db `exit 1\n`
    align 0x100, db 0

_macho_header:
    dd MH_MAGIC_64            ; magic
    dd CPU_TYPE_X86_64        ; cputype
    dd CPU_SUBTYPE_X86_64_ALL ; cpusubtype
    dd MH_EXECUTE             ; filetype
    dd 4                      ; ncmds
    dd _macho_commands_size   ; sizeofcmds
    dd MH_NOUNDEFS | MH_PIE   ; flags
    dd 0                      ; reserved

_macho_commands:
    _command_page_zero:
        dd LC_SEGMENT_64                  ; cmd
        dd _command_page_zero_size        ; cmdsize
        db "__PAGEZERO", 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                              ; vm address
        dq _macho_origin                  ; vm size
        dq 0                              ; file offset
        dq 0                              ; file size
        dd VM_PROT_NONE                   ; maximum protection
        dd VM_PROT_NONE                   ; inital protection
        dd 0                              ; number of _sections
        dd 0x0                            ; flags
    _command_page_zero_size equ $ - _command_page_zero

    _command_text_section:
        dd LC_SEGMENT_64                   ; command
        dd _command_text_section_size ; command size
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin                         ; vm address
        dq _header_raw_size + _section_text_raw_size          ; vm size
        dq 0                               ; file offset
        dq _header_raw_size + _section_text_raw_size          ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE  ; initial protection
        dd 1                               ; number of _sections
        dd 0x0                             ; flags

        db "__text", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__TEXT", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_text             ; address
        dq _section_text_size  ; size
        dd _section_text   ; offset
        dd 2                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    _command_text_section_size equ $ - _command_text_section

    _command_data_section:
        dd LC_SEGMENT_64                   ; command
        dd _command_data_section_size ; command size
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data                      ; vm address
        dq _section_data_raw_size       ; vm size
        dq _section_data             ; file offset
        dq _section_data_raw_size       ; file size
        dd VM_PROT_READ | VM_PROT_WRITE    ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE    ; initial protection
        dd 1                               ; number of _sections
        dd 0x0                             ; flags

        db "__data", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db "__DATA", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data             ; address
        dq _section_data_size  ; size
        dd _section_data                      ; offset
        dd 0                      ; align
        dd 0                      ; relocations offset
        dd 0                      ; number of relocations
        dd S_REGULAR              ; flags
        dd 0                      ; reserved1
        dd 0                      ; reserved2
        dd 0                      ; reserved3
    _command_data_section_size equ $ - _command_data_section

    _command_unix_thread:
        dd LC_UNIXTHREAD                                    ; cmd
        dd _command_unix_thread_size                        ; cmdsize
        dd x86_THREAD_STATE64                               ; flavour
        dd 42                                               ; count
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0           ; regs
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0           ; ...
        dq _macho_origin + macos__start, 0x0, 0x0, 0x0, 0x0 ; rip, ...
    _command_unix_thread_size equ $ - _command_unix_thread
_macho_commands_size equ $ - _macho_commands

_pe_header:
    db "PE", 0, 0               ; Signature
    dw 0x8664                   ; Machine
    dw 2                        ; NumberOfSections
    dd __?POSIX_TIME?__         ; TimeDateStamp
    dd 0                        ; PointerToSymbolTable
    dd 0                        ; NumberOfSymbols
    dw _pe_optional_header_size ; SizeOfOptionalHeader
    dw 0x030f                   ; Characteristics

_pe_optional_header:
    dw 0x020b                 ; Magic
    db 0                      ; MajorLinkerVersion
    db 0                      ; MinorLinkerVersion
    dd _section_text_raw_size ; SizeOfCode
    dd _section_data_raw_size ; SizeOfInitializedData
    dd 0                      ; SizeOfUninitializedData
    dd win32__start           ; AddressOfEntryPoint
    dd _section_text          ; BaseOfCode
    dq _pe_origin             ; ImageBase
    dd _alignment             ; SectionAlignment
    dd _alignment             ; FileAlignment
    dw 4                      ; MajorOperatingSystemVersion
    dw 0                      ; MinorOperatingSystemVersion
    dw 0                      ; MajorImageVersion
    dw 0                      ; MinorImageVersion
    dw 4                      ; MajorSubsystemVersion
    dw 0                      ; MinorSubsystemVersion
    dd 0                      ; Win32VersionValue
    dd _file_size             ; SizeOfImage
    dd _header_raw_size       ; SizeOfHeaders
    dd 0                      ; CheckSum
    dw 3                      ; Subsystem
    dw 0                      ; DllCharacteristics
    dq 0x100000               ; SizeOfStackReserve
    dq 0x1000                 ; SizeOfStackCommit
    dq 0x100000               ; SizeOfHeapReserve
    dq 0x1000                 ; SizeOfHeapCommit
    dd 0                      ; LoaderFlags
    dd 16                     ; NumberOfRvaAndSizes

    dd 0, 0
    dd _pe_import_table, _pe_import_table_size
    times 14 dd 0, 0
_pe_optional_header_size equ $ - _pe_optional_header

_pe_sections:
    db ".text", 0, 0, 0       ; Name
    dd _section_text_size     ; VirtualSize
    dd _section_text          ; VirtualAddress
    dd _section_text_raw_size ; SizeOfRawData
    dd _section_text          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd 0x60000020             ; Characteristics

    db ".data", 0, 0, 0       ; Name
    dd _section_data_size     ; VirtualSize
    dd _section_data          ; VirtualAddress
    dd _section_data_raw_size ; SizeOfRawData
    dd _section_data          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd 0xc0000040             ; Characteristics

_header_size equ $ - _header
    align _alignment, db 0
_header_raw_size equ $ - _header
%endmacro

%macro section_text 0
_section_text:
%endmacro
%macro section_text_end 0
_section_text_size equ $ - _section_text
    align _alignment, db 0
_section_text_raw_size equ $ - _section_text
%endmacro
%macro section_data 0
_section_data:
%endmacro
%macro section_data_end 0
_section_data_size equ $ - _section_data
    align _alignment, db 0
_section_data_raw_size equ $ - _section_data
%endmacro

; ####################################################################

header

section_text

; Windows Codes
win32__start:
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
macos__start:
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
    mov edi, stdout
    mov eax, macos_sys_write
    syscall

    leave
    ret

macos_exit:
    mov eax, macos_sys_exit
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

section_text_end

section_data

print dq 0
exit dq 0

message db `Hello World!`, 0
newline db `\n`, 0

_pe_import_table:
    dd 0, 0, 0, kernel32_name, kernel32_table
    dd 0, 0, 0, 0, 0

kernel32_table:
    ExitProcess dq _ExitProcess
    GetStdHandle dq _GetStdHandle
    WriteConsoleA dq _WriteConsoleA
    dq 0

    kernel32_name db "KERNEL32.DLL", 0
    _ExitProcess db 0, 0, "ExitProcess", 0
    _GetStdHandle db 0, 0, "GetStdHandle", 0
    _WriteConsoleA db 0, 0, "WriteConsoleA", 0

_pe_import_table_size equ $ - _pe_import_table

section_data_end

_file_size equ $
