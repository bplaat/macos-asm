#!/usr/bin/env python3
# A build script for ARM64 Mach-O assembly executables that ad-hoc signs the output.

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

PAGE_SIZE = 0x4000
HASH_SIZE = hashlib.sha256().digest_size
CODE_DIRECTORY_HEADER_SIZE = 88
SUPERBLOB_HEADER_SIZE = 20


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def assemble(
    source_file: Path,
    output_file: Path,
    identifier_size: int,
    signature_file: Path | None = None,
) -> None:
    args = [
        "nasm",
        "-f",
        "bin",
        "-D",
        f"SIGNATURE_IDENTIFIER_SIZE={identifier_size}",
    ]
    if signature_file is not None:
        args.extend(("-D", f'SIGNATURE_FILE="{signature_file}"'))
    args.extend((str(source_file), "-o", str(output_file)))
    run(*args)


def read_layout(macho: bytes) -> tuple[int, int, int]:
    magic, _, _, _, command_count, _, _, _ = struct.unpack_from("<8I", macho)
    if magic != 0xFEEDFACF:
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
    signature_size: int,
    executable_size: int,
) -> bytes:
    code_hashes = b"".join(
        hashlib.sha256(macho[offset : min(offset + PAGE_SIZE, code_limit)]).digest()
        for offset in range(0, code_limit, PAGE_SIZE)
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
        PAGE_SIZE.bit_length() - 1,
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
    if superblob_size > signature_size:
        raise ValueError(
            f"signature needs {superblob_size} bytes, Mach-O reserves {signature_size}"
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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build and ad-hoc sign an ARM64 Mach-O executable"
    )
    parser.add_argument("source", help="assembly source path, for example hello-arm64.s")
    args = parser.parse_args()

    source_file = Path(args.source).resolve()
    if not source_file.is_file():
        parser.error(f"source file not found: {source_file}")

    output_file = source_file.with_suffix("")
    identifier = output_file.name.encode("ascii") + b"\0"

    with tempfile.TemporaryDirectory(prefix=f"{output_file.name}.") as build_dir_name:
        build_dir = Path(build_dir_name)
        prefix_file = build_dir / f"{output_file.name}.prefix"
        signature_file = build_dir / "signature.bin"

        assemble(source_file, prefix_file, len(identifier))
        macho = prefix_file.read_bytes()
        code_limit, signature_size, executable_size = read_layout(macho)
        signature_file.write_bytes(
            make_signature(
                macho,
                identifier,
                code_limit,
                signature_size,
                executable_size,
            )
        )

        assemble(source_file, output_file, len(identifier), signature_file)

    os.chmod(output_file, output_file.stat().st_mode | stat.S_IXUSR)
    run(str(output_file))


if __name__ == "__main__":
    main()
