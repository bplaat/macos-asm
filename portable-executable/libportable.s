; A portable native executable library
; Written by Bastiaan van der Plaat (https://bplaat.nl/)

; MACH-O consts
%define MH_MAGIC_64 0xfeedfacf
%define MH_EXECUTE 2
%define MH_NOUNDEFS 0x0000001
%define MH_DYLDLINK 0x00000004
%define MH_PIE 0x00200000
%define CPU_TYPE_X86_64 0x01000007
%define CPU_SUBTYPE_X86_64_ALL 0x00000003
%define CPU_TYPE_ARM64 0x0100000c
%define CPU_SUBTYPE_ARM64_ALL 0x00000000

%define LC_REQ_DYLD 0x80000000
%define LC_SEGMENT_64 0x19
%define LC_SYMTAB 0x02
%define LC_UNIXTHREAD 0x05
%define LC_DYSYMTAB 0x0b
%define LC_LOAD_DYLIB 0xc
%define LC_LOAD_DYLINKER 0xe
%define LC_MAIN (0x28 | LC_REQ_DYLD)

%define VM_PROT_NONE 0x0
%define VM_PROT_READ 0x1
%define VM_PROT_WRITE 0x2
%define VM_PROT_EXECUTE 0x4

%define S_REGULAR 0x00000000
%define S_ATTR_PURE_INSTRUCTIONS 0x80000000
%define S_ATTR_SOME_INSTRUCTIONS 0x00000400
%define x86_THREAD_STATE64 0x4

; ELF consts
%define PT_LOAD 1
%define PF_X 1
%define PF_W 2
%define PF_R 4

; Program consts
%define NULL 0
%define STD_OUTPUT_HANDLE -11
%define stdout 1

%macro header 0
    _pe_origin equ 0x0000000000400000
    _macho_origin equ 0x0000000100000000
    _elf_origin equ 0x0000000100000000
    _alignment equ 0x4000

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
        db `if [ "$(arch)" = arm64 ]; then\n`
            db `dd if="$0" of="$0" bs=1 skip=2048 count=14336 conv=notrunc 2> /dev/null\n`
            db `codesign -s - "$0"\n`
        db `else\n`
            db `dd if="$0" of="$0" bs=1 skip=1280 count=15104 conv=notrunc 2> /dev/null\n`
        db `fi\n`
        db `exec "$0" "$@"\n`
    db `fi\n`
    db `if [ "$(uname -s)" = Linux ]; then\n`
        db `dd if="$0" of="$0" bs=1 skip=2816 count=13568 conv=notrunc 2> /dev/null\n`
        db `exec "$0" "$@"\n`
    db `fi\n`
    db `exit 1\n`
    align 0x100, db 0

; ########################################################################################

    ; PE header
_pe_header:
    db 'PE', 0, 0               ; Signature
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
    dd _win32_start           ; AddressOfEntryPoint
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
    dd _header_raw_size + _section_text_raw_size + _section_data_raw_size + _section_linkedit_raw_size ; SizeOfImage
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

_pesections:
    db '.text', 0, 0, 0       ; Name
    dd _section_text_size     ; VirtualSize
    dd _section_text          ; VirtualAddress
    dd _section_text_raw_size ; SizeOfRawData
    dd _section_text          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd 0x60000020             ; Characteristics

    db '.data', 0, 0, 0       ; Name
    dd _section_data_size     ; VirtualSize
    dd _section_data          ; VirtualAddress
    dd _section_data_raw_size ; SizeOfRawData
    dd _section_data          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd 0xc0000040             ; Characteristics

    align 0x100, db 0

; ########################################################################################

    ; MACH-O x86_64 header
_macho_x86_64_header:
    dd MH_MAGIC_64            ; magic
    dd CPU_TYPE_X86_64        ; cputype
    dd CPU_SUBTYPE_X86_64_ALL ; cpusubtype
    dd MH_EXECUTE             ; filetype
    dd 4                      ; ncmds
    dd _macho_x86_64_commands_size ; sizeofcmds
    dd MH_NOUNDEFS | MH_PIE   ; flags
    dd 0                      ; reserved

_macho_x86_64_commands:
    _x86_64_cmd_page_zero:
        dd LC_SEGMENT_64                  ; cmd
        dd _x86_64_cmd_page_zero_size        ; cmdsize
        db '__PAGEZERO', 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                              ; vm address
        dq _macho_origin                  ; vm size
        dq 0                              ; file offset
        dq 0                              ; file size
        dd VM_PROT_NONE                   ; maximum protection
        dd VM_PROT_NONE                   ; inital protection
        dd 0                              ; number of sections
        dd 0x0                            ; flags
    _x86_64_cmd_page_zero_size equ $ - _x86_64_cmd_page_zero

    _x86_64_cmd_section_text:
        dd LC_SEGMENT_64                             ; command
        dd _x86_64_cmd_section_text_size             ; command size
        db '__TEXT', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; segment name
        dq _macho_origin                             ; vm address
        dq _header_raw_size + _section_text_raw_size ; vm size
        dq 0                                         ; file offset
        dq _header_raw_size + _section_text_raw_size ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE            ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE            ; initial protection
        dd 1                                         ; number of sections
        dd 0x0                                       ; flags

        db '__text', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db '__TEXT', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_text          ; address
        dq _section_text_size                     ; size
        dd _section_text                          ; offset
        dd 2                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        times 3 dd 0                              ; reserved
    _x86_64_cmd_section_text_size equ $ - _x86_64_cmd_section_text

    _x86_64_cmd_section_data:
        dd LC_SEGMENT_64                          ; command
        dd _x86_64_cmd_section_data_size             ; command size
        db '__DATA', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data          ; vm address
        dq _section_data_raw_size                 ; vm size
        dq _section_data                          ; file offset
        dq _section_data_raw_size                 ; file size
        dd VM_PROT_READ | VM_PROT_WRITE           ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE           ; initial protection
        dd 1                                      ; number of sections
        dd 0x0                                    ; flags

        db '__data', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db '__DATA', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data          ; address
        dq _section_data_size                     ; size
        dd _section_data                          ; offset
        dd 0                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR                              ; flags
        times 3 dd 0                              ; reserved
    _x86_64_cmd_section_data_size equ $ - _x86_64_cmd_section_data

    _x86_64_cmd_unix_thread:
        dd LC_UNIXTHREAD                                    ; cmd
        dd _x86_64_cmd_unix_thread_size                        ; cmdsize
        dd x86_THREAD_STATE64                               ; flavour
        dd 42                                               ; count
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0           ; regs
        dq 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0           ; ...
        dq _macho_origin + _macos_start, 0x0, 0x0, 0x0, 0x0 ; rip, ...
    _x86_64_cmd_unix_thread_size equ $ - _x86_64_cmd_unix_thread
_macho_x86_64_commands_size equ $ - _macho_x86_64_commands

    align 0x100, db 0

; ########################################################################################

    ; MACH-O arm64 header
_macho_arm64_header:
    dd MH_MAGIC_64                        ; magic
    dd CPU_TYPE_ARM64                     ; cputype
    dd CPU_SUBTYPE_ARM64_ALL              ; cpusubtype
    dd MH_EXECUTE                         ; filetype
    dd 9                                  ; ncmds
    dd _macho_arm64_commands_size         ; sizeofcmds
    dd MH_NOUNDEFS | MH_DYLDLINK | MH_PIE ; flags
    dd 0                                  ; reserved

_macho_arm64_commands:
    _arm64_cmd_page_zero:
        dd LC_SEGMENT_64                  ; cmd
        dd _arm64_cmd_page_zero_size        ; cmdsize
        db '__PAGEZERO', 0, 0, 0, 0, 0, 0 ; segment name
        dq 0                              ; vm address
        dq _macho_origin                  ; vm size
        dq 0                              ; file offset
        dq 0                              ; file size
        dd VM_PROT_NONE                   ; maximum protection
        dd VM_PROT_NONE                   ; inital protection
        dd 0                              ; number of sections
        dd 0x0                            ; flags
    _arm64_cmd_page_zero_size equ $ - _arm64_cmd_page_zero

    _arm64_cmd_section_text:
        dd LC_SEGMENT_64                             ; command
        dd _arm64_cmd_section_text_size              ; command size
        db '__TEXT', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; segment name
        dq _macho_origin                             ; vm address
        dq _header_raw_size + _section_text_raw_size ; vm size
        dq 0                                         ; file offset
        dq _header_raw_size + _section_text_raw_size ; file size
        dd VM_PROT_READ | VM_PROT_EXECUTE            ; maximum protection
        dd VM_PROT_READ | VM_PROT_EXECUTE            ; initial protection
        dd 1                                         ; number of sections
        dd 0x0                                       ; flags

        db '__text', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db '__TEXT', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_text          ; address
        dq _section_text_size                     ; size
        dd _section_text                          ; offset
        dd 2                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS ; flags
        times 3 dd 0                              ; reserved
    _arm64_cmd_section_text_size equ $ - _arm64_cmd_section_text

    _arm64_cmd_section_data:
        dd LC_SEGMENT_64                          ; command
        dd _arm64_cmd_section_data_size             ; command size
        db '__DATA', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data          ; vm address
        dq _section_data_raw_size                 ; vm size
        dq _section_data                          ; file offset
        dq _section_data_raw_size                 ; file size
        dd VM_PROT_READ | VM_PROT_WRITE           ; maximum protection
        dd VM_PROT_READ | VM_PROT_WRITE           ; initial protection
        dd 1                                      ; number of sections
        dd 0x0                                    ; flags

        db '__data', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; section name
        db '__DATA', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; segment name
        dq _macho_origin + _section_data          ; address
        dq _section_data_size                     ; size
        dd _section_data                          ; offset
        dd 0                                      ; align
        dd 0                                      ; relocations offset
        dd 0                                      ; number of relocations
        dd S_REGULAR                              ; flags
        times 3 dd 0                              ; reserved
    _arm64_cmd_section_data_size equ $ - _arm64_cmd_section_data

    _arm64_cmd_section_linkedit:
        dd LC_SEGMENT_64                     ; command
        dd _arm64_cmd_section_linkedit_size  ; command size
        db "__LINKEDIT", 0, 0, 0, 0, 0, 0    ; segment name
        dq _macho_origin + _section_linkedit ; vm address
        dq _section_linkedit_raw_size        ; vm size
        dq _section_linkedit                 ; file offset
        dq _section_linkedit_raw_size        ; file size
        dd VM_PROT_READ                      ; maximum protection
        dd VM_PROT_READ                      ; initial protection
        dd 0                                 ; number of sections
        dd 0x0                               ; flags
    _arm64_cmd_section_linkedit_size equ $ - _arm64_cmd_section_linkedit

    _arm64_cmd_symtab:
        dd LC_SYMTAB              ; command
        dd _arm64_cmd_symtab_size ; command size
        times 4 dd 0              ; ?
    _arm64_cmd_symtab_size equ $ - _arm64_cmd_symtab

    _arm64_cmd_dysymtab:
        dd LC_DYSYMTAB              ; command
        dd _arm64_cmd_dysymtab_size ; command size
        times 18 dd 0               ; ?
    _arm64_cmd_dysymtab_size equ $ - _arm64_cmd_dysymtab

    _arm64_cmd_load_dylinker:
        dd LC_LOAD_DYLINKER              ; command
        dd _arm64_cmd_load_dylinker_size ; command size
        dd _arm64_cmd_load_dylinker_str - _arm64_cmd_load_dylinker ; string offet
    _arm64_cmd_load_dylinker_str:
        db '/usr/lib/dyld'
        align 8, db 0
    _arm64_cmd_load_dylinker_size equ $ - _arm64_cmd_load_dylinker

    _arm64_cmd_load_libsystem:
        dd LC_LOAD_DYLIB                  ; command
        dd _arm64_cmd_load_libsystem_size ; command size
        dd _arm64_cmd_load_libsystem_str - _arm64_cmd_load_libsystem ; string offset
        dd 0                              ; timestamp
        dw 0, 1                           ; current version
        dw 0, 1                           ; compatibility version
    _arm64_cmd_load_libsystem_str:
        db '/usr/lib/libSystem.B.dylib', 0
        align 8, db 0
    _arm64_cmd_load_libsystem_size equ $ - _arm64_cmd_load_libsystem

    _arm64_cmd_main:
        dd LC_MAIN              ; command
        dd _arm64_cmd_main_size ; command size
        dq _arm64_macos_start   ; entry point offset
        dq 0                    ; init stack size
    _arm64_cmd_main_size equ $ - _arm64_cmd_main
_macho_arm64_commands_size equ $ - _macho_arm64_commands

    align 0x100, db 0

; ########################################################################################

    ; ELF header
_elf_header:
    db 0x7f, 'ELF'                       ; e_ident[EI_MAG]
    db 2                                 ; e_ident[EI_CLASS]
    db 1                                 ; e_ident[EI_DATA]
    db 1                                 ; e_ident[EI_VERSION]
    db 0                                 ; e_ident[EI_OSABI]
    dq 0                                 ; e_ident[EI_ABIVERSION]
    dw 2                                 ; e_type
    dw 0x3e                              ; e_machine
    dd 1                                 ; e_version
    dq _elf_origin + _linux_start        ; e_entry
    dq _elf_program_header - _elf_header ; e_phoff
    dq 0                                 ; e_shoff
    dd 0                                 ; e_flags
    dw _elf_header_size                  ; e_ehsize
    dw _elf_program_entry_size           ; e_phentsize
    dw 2                                 ; e_phnum
    dw 0                                 ; e_shentsize
    dw 0                                 ; e_shnum
    dw 0                                 ; e_shstrndx
_elf_header_size equ $ - _elf_header

_elf_program_header:
    dd PT_LOAD                     ; p_type
    dd PF_R | PF_X                 ; p_flags
    dq _section_text               ; p_offset
    dq _elf_origin + _section_text ; p_vaddr
    dq _elf_origin + _section_text ; p_paddr
    dq _section_text_raw_size      ; p_filesz
    dq _section_text_raw_size      ; p_memsz
    dq _alignment                  ; p_align
_elf_program_entry_size equ $ - _elf_program_header

    dd PT_LOAD                     ; p_type
    dd PF_R | PF_W                 ; p_flags
    dq _section_data               ; p_offset
    dq _elf_origin + _section_data ; p_vaddr
    dq _elf_origin + _section_data ; p_paddr
    dq _section_data_raw_size      ; p_filesz
    dq _section_data_raw_size      ; p_memsz
    dq _alignment                  ; p_align

_header_size equ $ - _header
    align _alignment, db 0
_header_raw_size equ $ - _header
%endmacro

%macro section_text 0
_section_text:
%endmacro
%macro end_section_text 0
_section_text_size equ $ - _section_text
    align _alignment, db 0
_section_text_raw_size equ $ - _section_text
%endmacro

%macro section_data 0
_section_data:
%endmacro
%macro end_section_data 0
_section_data_size equ $ - _section_data
    align _alignment, db 0
_section_data_raw_size equ $ - _section_data
%endmacro

%macro footer 0
_section_linkedit:
    times _alignment db 0
_section_linkedit_raw_size equ $ - _section_linkedit
%endmacro
