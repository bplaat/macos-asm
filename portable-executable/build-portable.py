#!/usr/bin/env python3

import argparse
import hashlib
import os
import stat
import struct
import subprocess
import tempfile
from pathlib import Path


LC_CODE_SIGNATURE = 0x1D
LC_SEGMENT_64 = 0x19
CSMAGIC_CODEDIRECTORY = 0xFADE0C02
CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0
CS_ADHOC = 0x00002
CS_LINKER_SIGNED = 0x20000
CS_EXECSEG_MAIN_BINARY = 0x1
CS_HASHTYPE_SHA256 = 2
PLATFORM_MACOS = 1

MACHO_COPY_SIZE = 0x4000
ARM64_PAGE_SIZE = 0x4000
X86_64_PAGE_SIZE = 0x1000
HASH_SIZE = hashlib.sha256().digest_size
CODE_DIRECTORY_HEADER_SIZE = 88
SUPERBLOB_HEADER_SIZE = 20
SIGNATURE_ALIGNMENT = 16
MH_MAGIC_64 = 0xFEEDFACF
MH_EXECUTE = 2
CPU_TYPE_X86_64 = 0x01000007
CPU_SUBTYPE_X86_64_ALL = 3
CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64_ALL = 0


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def assemble(
    source_file: Path,
    output_file: Path,
    identifier_size: int,
    x86_64_signature_file: Path | None = None,
    arm64_signature_file: Path | None = None,
) -> None:
    args = [
        "nasm",
        "-f",
        "bin",
        "-I",
        f"{source_file.parent}{os.sep}",
        "-D",
        f"SIGNATURE_IDENTIFIER_SIZE={identifier_size}",
    ]
    if x86_64_signature_file is not None:
        args.extend(
            ("-D", f'MACHO_X86_64_SIGNATURE_FILE="{x86_64_signature_file}"')
        )
    if arm64_signature_file is not None:
        args.extend(("-D", f'MACHO_ARM64_SIGNATURE_FILE="{arm64_signature_file}"'))
    args.extend((str(source_file), "-o", str(output_file)))
    run(*args)


def read_layout(macho: bytes) -> tuple[int, int, int]:
    magic, _, _, _, command_count, _, _, _ = struct.unpack_from("<8I", macho)
    if magic != MH_MAGIC_64:
        raise ValueError("input is not a 64-bit Mach-O executable")

    offset = 32
    signature_layout = None
    executable_size = None
    for _ in range(command_count):
        command, command_size = struct.unpack_from("<2I", macho, offset)
        if command == LC_CODE_SIGNATURE:
            signature_layout = struct.unpack_from("<2I", macho, offset + 8)
        elif command == LC_SEGMENT_64:
            segment_name = macho[offset + 8 : offset + 24].rstrip(b"\0")
            if segment_name == b"__TEXT":
                executable_size = struct.unpack_from("<Q", macho, offset + 48)[0]
        offset += command_size

    if signature_layout is None or executable_size is None:
        raise ValueError("Mach-O signature or __TEXT layout is missing")
    return signature_layout[0], signature_layout[1], executable_size


def make_signature(
    macho: bytes,
    identifier: bytes,
    code_limit: int,
    signature_capacity: int,
    executable_size: int,
    page_size: int,
) -> bytes:
    code_hashes = b"".join(
        hashlib.sha256(macho[offset : min(offset + page_size, code_limit)]).digest()
        for offset in range(0, code_limit, page_size)
    )
    code_slots = len(code_hashes) // HASH_SIZE
    hash_offset = CODE_DIRECTORY_HEADER_SIZE + len(identifier)
    code_directory_size = hash_offset + len(code_hashes)

    code_directory = struct.pack(
        ">9I4B4I4Q",
        CSMAGIC_CODEDIRECTORY,
        code_directory_size,
        0x20400,
        CS_ADHOC | CS_LINKER_SIGNED,
        hash_offset,
        CODE_DIRECTORY_HEADER_SIZE,
        0,
        code_slots,
        code_limit,
        HASH_SIZE,
        CS_HASHTYPE_SHA256,
        PLATFORM_MACOS,
        page_size.bit_length() - 1,
        0,
        0,
        0,
        0,
        0,
        0,
        executable_size,
        CS_EXECSEG_MAIN_BINARY,
    )
    code_directory += identifier + code_hashes

    superblob_size = SUPERBLOB_HEADER_SIZE + len(code_directory)
    signature_size = (superblob_size + SIGNATURE_ALIGNMENT - 1) & ~(
        SIGNATURE_ALIGNMENT - 1
    )
    if signature_size > signature_capacity:
        raise ValueError(
            f"signature needs {signature_size} bytes, Mach-O reserves "
            f"{signature_capacity}"
        )

    signature = struct.pack(
        ">5I",
        CSMAGIC_EMBEDDED_SIGNATURE,
        superblob_size,
        1,
        0,
        SUPERBLOB_HEADER_SIZE,
    )
    return (signature + code_directory).ljust(signature_size, b"\0")


def make_macho_view(portable: bytes, cpu_type: int, cpu_subtype: int) -> bytes | None:
    header = struct.pack("<4I", MH_MAGIC_64, cpu_type, cpu_subtype, MH_EXECUTE)
    header_offset = portable.find(header)
    if header_offset < 0:
        return None

    header_end = header_offset + MACHO_COPY_SIZE
    if header_end > len(portable):
        raise ValueError("embedded Mach-O header copy extends beyond the portable file")

    macho = bytearray(portable)
    macho[:MACHO_COPY_SIZE] = portable[header_offset:header_end]
    return bytes(macho)


def write_signature(
    portable_file: Path,
    signature_file: Path,
    identifier: bytes,
    cpu_type: int,
    cpu_subtype: int,
    page_size: int,
) -> bool:
    macho = make_macho_view(portable_file.read_bytes(), cpu_type, cpu_subtype)
    if macho is None:
        return False

    code_limit, signature_capacity, executable_size = read_layout(macho)
    signature_file.write_bytes(
        make_signature(
            macho,
            identifier,
            code_limit,
            signature_capacity,
            executable_size,
            page_size,
        )
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build and ad-hoc sign embedded Mach-O portable executables"
    )
    parser.add_argument("source", help="assembly source path, for example hello.s")
    args = parser.parse_args()

    source_file = Path(args.source).resolve()
    if not source_file.is_file():
        parser.error(f"source file not found: {source_file}")

    output_file = source_file.with_suffix(".com")
    identifier = output_file.name.encode("ascii") + b"\0"

    with tempfile.TemporaryDirectory(prefix=f"{output_file.stem}.") as build_dir_name:
        build_dir = Path(build_dir_name)
        prefix_file = build_dir / "prefix.com"
        x86_64_signature_file = build_dir / "x86_64-signature.bin"
        arm64_signature_file = build_dir / "arm64-signature.bin"

        assemble(source_file, prefix_file, len(identifier))
        has_x86_64 = write_signature(
            prefix_file,
            x86_64_signature_file,
            identifier,
            CPU_TYPE_X86_64,
            CPU_SUBTYPE_X86_64_ALL,
            X86_64_PAGE_SIZE,
        )
        if not has_x86_64:
            raise ValueError("embedded x86_64 Mach-O header is missing")

        assemble(
            source_file,
            prefix_file,
            len(identifier),
            x86_64_signature_file,
        )
        has_arm64 = write_signature(
            prefix_file,
            arm64_signature_file,
            identifier,
            CPU_TYPE_ARM64,
            CPU_SUBTYPE_ARM64_ALL,
            ARM64_PAGE_SIZE,
        )

        assemble(
            source_file,
            output_file,
            len(identifier),
            x86_64_signature_file,
            arm64_signature_file if has_arm64 else None,
        )

    os.chmod(output_file, output_file.stat().st_mode | stat.S_IXUSR)


if __name__ == "__main__":
    main()
