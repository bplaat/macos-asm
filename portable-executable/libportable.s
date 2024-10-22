; A portable native executable library
; Written by Bastiaan van der Plaat (https://bplaat.nl/)

; PE consts
%define IMAGE_FILE_RELOCS_STRIPPED 0x0001
%define IMAGE_FILE_EXECUTABLE_IMAGE 0x0002
%define IMAGE_FILE_LINE_NUMS_STRIPPED 0x0004
%define IMAGE_FILE_LOCAL_SYMS_STRIPPED 0x0008
%define IMAGE_FILE_LARGE_ADDRESS_AWARE 0x0020
%define IMAGE_FILE_DEBUG_STRIPPED 0x0200

%define IMAGE_SUBSYSTEM_WINDOWS_CUI 3

%define IMAGE_SCN_CNT_CODE 0x00000020
%define IMAGE_SCN_CNT_INITIALIZED_DATA 0x00000040
%define IMAGE_SCN_MEM_EXECUTE 0x20000000
%define IMAGE_SCN_MEM_READ 0x40000000
%define IMAGE_SCN_MEM_WRITE 0x80000000

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
%define LC_DYSYMTAB 0x0b
%define LC_LOAD_DYLIB 0xc
%define LC_LOAD_DYLINKER 0xe
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
%define BIND_OPCODE_DONE 0x00

; ELF consts
%define ELF_CLASS_64 2
%define ELF_DATA_LITTLE_ENDIAN 1
%define ELF_TYPE_EXECUTE 2
%define ELF_MACHINE_X86_64 0x3e
%define ELF_MACHINE_AARCH64 0xb7

%define PT_LOAD 1
%define PF_X 1
%define PF_W 2
%define PF_R 4

%define SHT_NULL 0
%define SHT_PROGBITS 1
%define SHT_STRTAB 3
%define SHF_WRITE 1
%define SHF_ALLOC 2
%define SHF_EXECINSTR 4

%macro number_ascii 1
    db %1 >= 10000 ? ((%1 / 10000) % 10) + 0x30 : ' '
    db %1 >= 1000 ? ((%1 / 1000) % 10) + 0x30 : ' '
    db %1 >= 100 ? ((%1 / 100) % 10) + 0x30 : ' '
    db %1 >= 10 ? ((%1 / 10) % 10) + 0x30 : ' '
    db (%1 % 10) + 0x30
%endmacro

%macro macho_library 2
    ._cmd_load_%1:
        dd LC_LOAD_DYLIB                     ; command
        dd ._cmd_load_%1_size                ; command size
        dd ._cmd_load_%1_str - ._cmd_load_%1 ; string offset
        dd 0                                 ; timestamp
        dw 0, 1                              ; current version
        dw 0, 1                              ; compatibility version
    ._cmd_load_%1_str:
        db %2, 0
        align 8, db 0
    ._cmd_load_%1_size equ $ - ._cmd_load_%1
%endmacro

%define HEADER_X86_64 1
%define HEADER_ARM64 2

%macro header 1
    _pe_origin equ 0x0000000000400000
    _macho_origin equ 0x0000000100000000
    _elf_origin equ 0x0000000000400000
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

    ; Msys
    db `if [ "$(uname -o)" = Msys ]; then\n`
        db `exec "$0" "$@"\n`
    db `fi\n`

    ; macOS
    db `if [ "$(uname -s)" = Darwin ]; then\n`
        %if (%1 & HEADER_ARM64) != 0
        db `if [ "$(arch)" = arm64 ]; then\n`
            db `dd if="$0" of="$0" bs=1 skip="`
            number_ascii (_macho_arm64_header - _header)
            db `" count="`
            number_ascii _alignment
            db `" conv=notrunc 2> /dev/null\n`
            db `codesign -s - "$0"\n`
        db `else\n`
        %endif
            db `dd if="$0" of="$0" bs=1 skip="`
            number_ascii (_macho_x86_64_header - _header)
            db `" count="`
            number_ascii _alignment
            db `" conv=notrunc 2> /dev/null\n`
        %if (%1 & HEADER_ARM64) != 0
        db `fi\n`
        %endif
        db `exec "$0" "$@"\n`
    db `fi\n`

    ; Linux
    db `if [ "$(uname -s)" = Linux ]; then\n`
        %if (%1 & HEADER_ARM64) != 0
        db `if [ "$(uname -m)" = aarch64 ]; then\n`
            db `dd if="$0" of="$0" bs=1 skip="`
            number_ascii (_elf_arm64_header - _header)
            db `" count="`
            number_ascii _alignment
            db `" conv=notrunc 2> /dev/null\n`
        db `else\n`
        %endif
            db `dd if="$0" of="$0" bs=1 skip="`
            number_ascii (_elf_x86_64_header - _header)
            db `" count="`
            number_ascii _alignment
            db `" conv=notrunc 2> /dev/null\n`
        %if (%1 & HEADER_ARM64) != 0
        db `fi\n`
        %endif
        db `exec "$0" "$@"\n`
    db `fi\n`

    ; Just fail
    db `exit 1\n`
    align 8, db 0

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
    dw IMAGE_FILE_RELOCS_STRIPPED | IMAGE_FILE_EXECUTABLE_IMAGE | IMAGE_FILE_LINE_NUMS_STRIPPED | IMAGE_FILE_LOCAL_SYMS_STRIPPED | IMAGE_FILE_LARGE_ADDRESS_AWARE | IMAGE_FILE_DEBUG_STRIPPED ; Characteristics

_pe_optional_header:
    dw 0x020b                      ; Magic
    db 0                           ; MajorLinkerVersion
    db 0                           ; MinorLinkerVersion
    dd _section_text_raw_size      ; SizeOfCode
    dd _section_data_raw_size      ; SizeOfInitializedData
    dd 0                           ; SizeOfUninitializedData
    dd _windows_start              ; AddressOfEntryPoint
    dd _section_text               ; BaseOfCode
    dq _pe_origin                  ; ImageBase
    dd _alignment                  ; SectionAlignment
    dd _alignment                  ; FileAlignment
    dw 4                           ; MajorOperatingSystemVersion
    dw 0                           ; MinorOperatingSystemVersion
    dw 0                           ; MajorImageVersion
    dw 0                           ; MinorImageVersion
    dw 4                           ; MajorSubsystemVersion
    dw 0                           ; MinorSubsystemVersion
    dd 0                           ; Win32VersionValue
    dd _header_raw_size + _section_text_raw_size + _section_data_raw_size + _section_linkedit_raw_size ; SizeOfImage
    dd _header_raw_size            ; SizeOfHeaders
    dd 0                           ; CheckSum
    dw IMAGE_SUBSYSTEM_WINDOWS_CUI ; Subsystem
    dw 0                           ; DllCharacteristics
    dq 0x100000                    ; SizeOfStackReserve
    dq 0x1000                      ; SizeOfStackCommit
    dq 0x100000                    ; SizeOfHeapReserve
    dq 0x1000                      ; SizeOfHeapCommit
    dd 0                           ; LoaderFlags
    dd 16                          ; NumberOfRvaAndSizes

    dd 0, 0
    dd _pe_import_table, _pe_import_table_size
    times 14 dd 0, 0
_pe_optional_header_size equ $ - _pe_optional_header

_pe_sections:
    db '.text', 0, 0, 0       ; Name
    dd _section_text_size     ; VirtualSize
    dd _section_text          ; VirtualAddress
    dd _section_text_raw_size ; SizeOfRawData
    dd _section_text          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_CNT_CODE ; Characteristics

    db '.data', 0, 0, 0       ; Name
    dd _section_data_size     ; VirtualSize
    dd _section_data          ; VirtualAddress
    dd _section_data_raw_size ; SizeOfRawData
    dd _section_data          ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE | IMAGE_SCN_CNT_INITIALIZED_DATA ; Characteristics

; ########################################################################################

    ; MACH-O x86_64 header
_macho_x86_64_header:
    dd MH_MAGIC_64                        ; magic
    dd CPU_TYPE_X86_64                    ; cputype
    dd CPU_SUBTYPE_X86_64_ALL             ; cpusubtype
    dd MH_EXECUTE                         ; filetype
    %ifmacro macho_bindings
        %ifmacro macho_libraries
            dd 10 + macho_libraries_count  ; ncmds
        %else
            dd 10 + 1                      ; ncmds
        %endif
    %else
        %ifmacro macho_libraries
            dd 9 + macho_libraries_count  ; ncmds
        %else
            dd 9 + 1                      ; ncmds
        %endif
    %endif
    dd _macho_x86_64_commands_size        ; sizeofcmds
    dd MH_NOUNDEFS | MH_DYLDLINK | MH_PIE ; flags
    dd 0                                  ; reserved

_macho_x86_64_commands:
    _x86_64_cmd_page_zero:
        dd LC_SEGMENT_64                  ; cmd
        dd _x86_64_cmd_page_zero_size     ; cmdsize
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
        dd _x86_64_cmd_section_data_size          ; command size
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

    _x86_64_cmd_section_linkedit:
        dd LC_SEGMENT_64                     ; command
        dd _x86_64_cmd_section_linkedit_size ; command size
        db "__LINKEDIT", 0, 0, 0, 0, 0, 0    ; segment name
        dq _macho_origin + _section_linkedit ; vm address
        dq _section_linkedit_raw_size        ; vm size
        dq _section_linkedit                 ; file offset
        dq _section_linkedit_raw_size        ; file size
        dd VM_PROT_READ                      ; maximum protection
        dd VM_PROT_READ                      ; initial protection
        dd 0                                 ; number of sections
        dd 0x0                               ; flags
    _x86_64_cmd_section_linkedit_size equ $ - _x86_64_cmd_section_linkedit

    _x86_64_cmd_symtab:
        dd LC_SYMTAB               ; command
        dd _x86_64_cmd_symtab_size ; command size
        times 4 dd 0               ; ?
    _x86_64_cmd_symtab_size equ $ - _x86_64_cmd_symtab

    _x86_64_cmd_dysymtab:
        dd LC_DYSYMTAB               ; command
        dd _x86_64_cmd_dysymtab_size ; command size
        times 18 dd 0                ; ?
    _x86_64_cmd_dysymtab_size equ $ - _x86_64_cmd_dysymtab

    _x86_64_build_version:
        dd LC_BUILD_VERSION                                  ; command
        dd _x86_64_build_version_end - _x86_64_build_version ; command size
        dd PLATFORM_MACOS                                    ; platform
        dw 0, 11                                             ; minos
        dw 0, 11                                             ; sdk
        dd 1                                                 ; ntools
        dd TOOL_LD                                           ; tool type
        dw 0, 1                                              ; tool version
    _x86_64_build_version_end:

    _x86_64_cmd_load_dylinker:
        dd LC_LOAD_DYLINKER               ; command
        dd _x86_64_cmd_load_dylinker_size ; command size
        dd _x86_64_cmd_load_dylinker_str - _x86_64_cmd_load_dylinker ; string offset
    _x86_64_cmd_load_dylinker_str:
        db '/usr/lib/dyld', 0
        align 8, db 0
    _x86_64_cmd_load_dylinker_size equ $ - _x86_64_cmd_load_dylinker

    %ifmacro macho_libraries
        macho_libraries
    %else
        macho_library libsystem, '/usr/lib/libSystem.B.dylib'
    %endif

    %ifmacro macho_bindings
        _x86_64_cmd_dyld_info:
            dd LC_DYLD_INFO_ONLY          ; command
            dd _x86_64_cmd_dyld_info_size ; command size
            times 2 dd 0
            dd _macho_bindings            ; bindings offset
            dd _macho_bindings_size       ; bindings size
            times 6 dd 0
        _x86_64_cmd_dyld_info_size equ $ - _x86_64_cmd_dyld_info
    %endif

    _x86_64_cmd_main:
        dd LC_MAIN               ; command
        dd _x86_64_cmd_main_size ; command size
        dq _macos_start          ; entry point offset
        dq 0                     ; init stack size
    _x86_64_cmd_main_size equ $ - _x86_64_cmd_main
_macho_x86_64_commands_size equ $ - _macho_x86_64_commands

; ########################################################################################

%if (%1 & HEADER_ARM64) != 0
    ; MACH-O arm64 header
_macho_arm64_header:
    dd MH_MAGIC_64                        ; magic
    dd CPU_TYPE_ARM64                     ; cputype
    dd CPU_SUBTYPE_ARM64_ALL              ; cpusubtype
    dd MH_EXECUTE                         ; filetype
    %ifmacro macho_bindings
        %ifmacro macho_libraries
            dd 10 + macho_libraries_count  ; ncmds
        %else
            dd 10 + 1                      ; ncmds
        %endif
    %else
        %ifmacro macho_libraries
            dd 9 + macho_libraries_count  ; ncmds
        %else
            dd 9 + 1                      ; ncmds
        %endif
    %endif
    dd _macho_arm64_commands_size         ; sizeofcmds
    dd MH_NOUNDEFS | MH_DYLDLINK | MH_PIE ; flags
    dd 0                                  ; reserved

_macho_arm64_commands:
    _arm64_cmd_page_zero:
        dd LC_SEGMENT_64                  ; cmd
        dd _arm64_cmd_page_zero_size      ; cmdsize
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
        dd _arm64_cmd_section_data_size           ; command size
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

    _arm64_build_version:
        dd LC_BUILD_VERSION                                ; command
        dd _arm64_build_version_end - _arm64_build_version ; command size
        dd PLATFORM_MACOS                                  ; platform
        dw 0, 11                                           ; minos
        dw 0, 11                                           ; sdk
        dd 1                                               ; ntools (should be at least 1)
        dd TOOL_LD                                         ; tool type: ld
        dw 0, 1                                            ; tool version
    _arm64_build_version_end:

    _arm64_cmd_load_dylinker:
        dd LC_LOAD_DYLINKER              ; command
        dd _arm64_cmd_load_dylinker_size ; command size
        dd _arm64_cmd_load_dylinker_str - _arm64_cmd_load_dylinker ; string offset
    _arm64_cmd_load_dylinker_str:
        db '/usr/lib/dyld', 0
        align 8, db 0
    _arm64_cmd_load_dylinker_size equ $ - _arm64_cmd_load_dylinker

    %ifmacro macho_libraries
        macho_libraries
    %else
        macho_library libsystem, '/usr/lib/libSystem.B.dylib'
    %endif

    %ifmacro macho_bindings
        _arm64_cmd_dyld_info:
            dd LC_DYLD_INFO_ONLY         ; command
            dd _arm64_cmd_dyld_info_size ; command size
            times 2 dd 0
            dd _macho_bindings           ; bindings offset
            dd _macho_bindings_size      ; bindings size
            times 6 dd 0
        _arm64_cmd_dyld_info_size equ $ - _arm64_cmd_dyld_info
    %endif

    _arm64_cmd_main:
        dd LC_MAIN              ; command
        dd _arm64_cmd_main_size ; command size
        dq _arm64_macos_start   ; entry point offset
        dq 0                    ; init stack size
    _arm64_cmd_main_size equ $ - _arm64_cmd_main
_macho_arm64_commands_size equ $ - _macho_arm64_commands
%endif

; ########################################################################################

    ; ELF x86_64 header
_elf_x86_64_header:
    db 0x7f, 'ELF'                       ; e_ident[EI_MAG]
    db ELF_CLASS_64                      ; e_ident[EI_CLASS]
    db ELF_DATA_LITTLE_ENDIAN            ; e_ident[EI_DATA]
    db 1                                 ; e_ident[EI_VERSION]
    db 0                                 ; e_ident[EI_OSABI]
    dq 0                                 ; e_ident[EI_ABIVERSION]
    dw ELF_TYPE_EXECUTE                  ; e_type
    dw ELF_MACHINE_X86_64                ; e_machine
    dd 1                                 ; e_version
    dq _elf_origin + _linux_start        ; e_entry
    dq _elf_program_header - _elf_x86_64_header ; e_phoff
    dq _elf_section_header - _elf_x86_64_header ; e_shoff
    dd 0                                 ; e_flags
    dw _elf_x86_64_header_size           ; e_ehsize
    dw _elf_program_entry_size           ; e_phentsize
    dw 2                                 ; e_phnum
    dw _elf_section_entry_size           ; e_shentsize
    dw 4                                 ; e_shnum
    dw 3                                 ; e_shstrndx
_elf_x86_64_header_size equ $ - _elf_x86_64_header

%if (%1 & HEADER_ARM64) != 0
    ; ELF arm64 header
_elf_arm64_header:
    db 0x7f, 'ELF'                       ; e_ident[EI_MAG]
    db ELF_CLASS_64                      ; e_ident[EI_CLASS]
    db ELF_DATA_LITTLE_ENDIAN            ; e_ident[EI_DATA]
    db 1                                 ; e_ident[EI_VERSION]
    db 0                                 ; e_ident[EI_OSABI]
    dq 0                                 ; e_ident[EI_ABIVERSION]
    dw ELF_TYPE_EXECUTE                  ; e_type
    dw ELF_MACHINE_AARCH64               ; e_machine
    dd 1                                 ; e_version
    dq _elf_origin + _arm64_linux_start  ; e_entry
    dq _elf_program_header - _elf_arm64_header ; e_phoff
    dq _elf_section_header - _elf_arm64_header ; e_shoff
    dd 0                                 ; e_flags
    dw _elf_arm64_header_size            ; e_ehsize
    dw _elf_program_entry_size           ; e_phentsize
    dw 2                                 ; e_phnum
    dw _elf_section_entry_size           ; e_shentsize
    dw 4                                 ; e_shnum
    dw 3                                 ; e_shstrndx
_elf_arm64_header_size equ $ - _elf_arm64_header
%endif

    ; Shared ELF program header
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

    ; Shared ELF section header
_elf_section_header:
    dd _elf_null_name - _elf_section_names ; sh_name
    dd SHT_NULL ; sh_type
    dq 0        ; sh_flags
    dq 0        ; sh_addr
    dq 0        ; sh_offset
    dq 0        ; sh_size
    dd 0        ; sh_link
    dd 0        ; sh_info
    dq 0        ; sh_addralign
    dq 0        ; sh_entsize
_elf_section_entry_size equ $ - _elf_section_header

    dd _elf_text_name - _elf_section_names ; sh_name
    dd SHT_PROGBITS                ; sh_type
    dq SHF_ALLOC | SHF_EXECINSTR   ; sh_flags
    dq _elf_origin + _section_text ; sh_addr
    dq _section_text               ; sh_offset
    dq _section_text_size          ; sh_size
    dd 0                           ; sh_link
    dd 0                           ; sh_info
    dq _alignment                  ; sh_addralign
    dq 0                           ; sh_entsize

    dd _elf_data_name - _elf_section_names ; sh_name
    dd SHT_PROGBITS                ; sh_type
    dq SHF_ALLOC | SHF_WRITE       ; sh_flags
    dq _elf_origin + _section_data ; sh_addr
    dq _section_data               ; sh_offset
    dq _section_data_size          ; sh_size
    dd 0                           ; sh_link
    dd 0                           ; sh_info
    dq _alignment                  ; sh_addralign
    dq 0                           ; sh_entsize

    dd _elf_shstrtab_name - _elf_section_names ; sh_name
    dd SHT_STRTAB              ; sh_type
    dq 0                       ; sh_flags
    dq 0                       ; sh_addr
    dq _elf_section_names      ; sh_offset
    dq _elf_section_names_size ; sh_size
    dd 0                       ; sh_link
    dd 0                       ; sh_info
    dq 1                       ; sh_addralign
    dq 0                       ; sh_entsize

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

%macro ms_abi_stub 2
%1:
    sub rsp, (((%2 > 4 ? %2 : 4) * 8) + 15) & (~15)
    %if %2 >= 6
        mov qword [rsp + 5 * 8], r9
    %endif
    %if %2 >= 5
        mov qword [rsp + 4 * 8], r8
    %endif
    %if %2 >= 4
        mov r9, rcx
    %endif
    %if %2 >= 3
        mov r8, rdx
    %endif
    %if %2 >= 2
        mov rdx, rsi
    %endif
    %if %2 >= 1
        mov rcx, rdi
    %endif
    call [rel @%1]
    add rsp, (((%2 > 4 ? %2 : 4) * 8) + 15) & (~15)
    ret
%endmacro

%macro section_data 0
_section_data:
%endmacro
%macro end_section_data 0
_section_data_size equ $ - _section_data

_elf_section_names:
_elf_null_name:
    db 0
_elf_text_name:
    db '.text', 0
_elf_data_name:
    db '.data', 0
_elf_shstrtab_name:
    db '.shstrtab', 0
_elf_section_names_size equ $ - _elf_section_names

    align _alignment, db 0
_section_data_raw_size equ $ - _section_data
%endmacro

%macro pe_import_table 0
_pe_import_table:
%endmacro
%macro end_pe_import_table 0
_pe_import_table_size equ $ - _pe_import_table
%endmacro

%macro pe_library 2-*
    %rep %0 / 2
        dd 0, 0, 0, _%1, %1
        %rotate 2
    %endrep
    dd 0, 0, 0, 0, 0

    %rep %0 / 2
        _%1 db %2, 0
        %rotate 2
    %endrep
%endmacro

%macro pe_import 3-*
%1:
    %rotate 1
    %rep (%0 - 1) / 2
        @%1 dq _%1
        %rotate 2
    %endrep
    dq 0

    %rotate 1
    %rep (%0 - 1) / 2
        _%1 db 0, 0, %2, 0
        %rotate 2
    %endrep
%endmacro

%macro footer 0
_section_linkedit:
%ifmacro macho_bindings
_macho_bindings:
    macho_bindings
_macho_bindings_size equ $ - _macho_bindings
%else
    db 0
%endif
    times _alignment db 0
_section_linkedit_raw_size equ $ - _section_linkedit
%endmacro
