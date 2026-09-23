#!/usr/bin/env python3

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
CSMAGIC_EMBEDDED_ENTITLEMENTS = 0xFADE7171
CS_ADHOC = 0x00002
CS_LINKER_SIGNED = 0x20000
CS_EXECSEG_MAIN_BINARY = 0x1
CS_HASHTYPE_SHA256 = 2

PAGE_SIZE = 0x1000
HASH_SIZE = hashlib.sha256().digest_size
CODE_DIRECTORY_HEADER_SIZE = 88
SPECIAL_SLOTS = 5
SUPERBLOB_HEADER_SIZE = 28
CODE_RESOURCES = rb"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>files</key><dict/>
    <key>files2</key><dict/>
    <key>rules</key>
    <dict>
        <key>^Resources/</key><true/>
        <key>^version.plist$</key><true/>
    </dict>
    <key>rules2</key>
    <dict>
        <key>^.*</key><true/>
        <key>^Info\.plist$</key>
        <dict><key>omit</key><true/><key>weight</key><integer>20</integer></dict>
        <key>^MacOS/</key>
        <dict><key>nested</key><true/><key>weight</key><integer>10</integer></dict>
    </dict>
</dict>
</plist>
"""


def assemble(source: Path, output: Path, identifier_size: int,
             entitlements_size: int, signature: Path | None = None) -> None:
    args = [
        "nasm", "-f", "bin",
        "-D", f"SIGNATURE_IDENTIFIER_SIZE={identifier_size}",
        "-D", f"SIGNATURE_ENTITLEMENTS_SIZE={entitlements_size}",
    ]
    if signature is not None:
        args.extend(("-D", f'SIGNATURE_FILE="{signature}"'))
    subprocess.run([*args, str(source), "-o", str(output)], check=True)


def read_layout(macho: bytes) -> tuple[int, int, int]:
    magic, cpu_type, _, _, command_count, _, _, _ = struct.unpack_from("<8I", macho)
    if magic != 0xFEEDFACF or cpu_type != 0x01000007:
        raise ValueError("input is not an x86_64 Mach-O executable")

    offset = 32
    signature_layout = None
    executable_size = None
    for _ in range(command_count):
        command, command_size = struct.unpack_from("<2I", macho, offset)
        if command == LC_CODE_SIGNATURE:
            signature_layout = struct.unpack_from("<2I", macho, offset + 8)
        elif command == LC_SEGMENT_64:
            if macho[offset + 8:offset + 24].rstrip(b"\0") == b"__TEXT":
                executable_size = struct.unpack_from("<Q", macho, offset + 48)[0]
        offset += command_size

    if signature_layout is None or executable_size is None:
        raise ValueError("Mach-O signature or __TEXT layout is missing")
    return signature_layout[0], signature_layout[1], executable_size


def make_signature(macho: bytes, identifier: bytes, info: bytes,
                   resources: bytes, entitlements: bytes, code_limit: int,
                   signature_size: int, executable_size: int) -> bytes:
    entitlements_blob = struct.pack(">2I", CSMAGIC_EMBEDDED_ENTITLEMENTS,
                                    8 + len(entitlements)) + entitlements
    special_hashes = (
        hashlib.sha256(entitlements_blob).digest()
        + bytes(HASH_SIZE)
        + hashlib.sha256(resources).digest()
        + bytes(HASH_SIZE)
        + hashlib.sha256(info).digest()
    )
    code_hashes = b"".join(
        hashlib.sha256(macho[offset:min(offset + PAGE_SIZE, code_limit)]).digest()
        for offset in range(0, code_limit, PAGE_SIZE)
    )
    code_slots = len(code_hashes) // HASH_SIZE
    hash_offset = CODE_DIRECTORY_HEADER_SIZE + len(identifier) + len(special_hashes)
    code_directory_size = hash_offset + len(code_hashes)

    code_directory = struct.pack(
        ">9I4B4I4Q",
        CSMAGIC_CODEDIRECTORY,
        code_directory_size,
        0x20400,
        CS_ADHOC | CS_LINKER_SIGNED,
        hash_offset,
        CODE_DIRECTORY_HEADER_SIZE,
        SPECIAL_SLOTS,
        code_slots,
        code_limit,
        HASH_SIZE,
        CS_HASHTYPE_SHA256,
        0,
        PAGE_SIZE.bit_length() - 1,
        0, 0, 0, 0, 0, 0,
        executable_size,
        CS_EXECSEG_MAIN_BINARY,
    )
    code_directory += identifier + special_hashes + code_hashes

    superblob_size = SUPERBLOB_HEADER_SIZE + len(code_directory) + len(entitlements_blob)
    if superblob_size > signature_size:
        raise ValueError(f"signature needs {superblob_size} bytes, Mach-O reserves {signature_size}")

    signature = struct.pack(
        ">7I",
        CSMAGIC_EMBEDDED_SIGNATURE,
        superblob_size,
        2,
        0,
        SUPERBLOB_HEADER_SIZE,
        5,
        SUPERBLOB_HEADER_SIZE + len(code_directory),
    )
    return (signature + code_directory + entitlements_blob).ljust(signature_size, b"\0")


def main() -> None:
    directory = Path(__file__).resolve().parent
    source = directory / "alert.s"
    info_source = directory / "Info.plist"
    executable_name = subprocess.check_output(
        ["plutil", "-extract", "CFBundleExecutable", "raw", str(info_source)],
        text=True,
    ).strip()
    identifier = subprocess.check_output(
        ["plutil", "-extract", "CFBundleIdentifier", "raw", str(info_source)],
        text=True,
    ).strip().encode("ascii") + b"\0"
    bundle = directory / f"{executable_name}.app"
    info_path = bundle / "Contents" / "Info.plist"
    info_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["plutil", "-convert", "binary1", "-o", str(info_path), str(info_source)],
        check=True,
    )
    info = info_path.read_bytes()
    entitlements = (directory / "Entitlements.plist").read_bytes()
    output = bundle / "Contents" / "MacOS" / executable_name
    output.parent.mkdir(parents=True, exist_ok=True)

    resources = CODE_RESOURCES
    resources_path = bundle / "Contents" / "_CodeSignature" / "CodeResources"
    resources_path.parent.mkdir(parents=True, exist_ok=True)
    resources_path.write_bytes(resources)

    with tempfile.TemporaryDirectory(prefix=f"{executable_name}.") as directory:
        prefix = Path(directory) / "prefix"
        signature_file = Path(directory) / "signature.bin"
        assemble(source, prefix, len(identifier), len(entitlements))
        macho = prefix.read_bytes()
        code_limit, signature_size, executable_size = read_layout(macho)
        signature_file.write_bytes(make_signature(
            macho, identifier, info, resources, entitlements,
            code_limit, signature_size, executable_size,
        ))
        assemble(source, output, len(identifier), len(entitlements), signature_file)

    os.chmod(output, output.stat().st_mode | stat.S_IXUSR)
    subprocess.run(["open", str(bundle)], check=True)


if __name__ == "__main__":
    main()
