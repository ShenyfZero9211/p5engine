#!/usr/bin/env python3
"""
PPAK - Processing PAKage format library

A package format for bundling Processing sketches and resources,
providing version control friendly management and easy distribution.

File Format (Little Endian):
+----------- 4 bytes --------+----------- 2 bytes --------+
|         MAGIC (b'PPAK')   |       VERSION (1)         |
+---------------------------+---------------------------+
|          ENTRY COUNT      |      RESERVED (4 bytes)   |
+---------------------------+---------------------------+
|                    INDEX SECTION                        |
|  [Offset:4] [Size:4] [NameLen:2] [Name:NameLen]  ...     |
+---------------------------+---------------------------+
|                    DATA SECTION                         |
|                   (raw file data)                      |
+-------------------------------------------------------+

Author: Processing PPAK System
"""

import struct
import os
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, field

MAGIC = b"PPAK"
VERSION = 1
HEADER_SIZE = 12
INDEX_ENTRY_SIZE = 10

PACK_METADATA_FILE = ".ppak_meta.json"


@dataclass
class PPAKEntry:
    path: str
    offset: int
    size: int
    data: bytes = field(default=None)


@dataclass
class PPAKManifest:
    name: str
    version: str
    author: str = ""
    description: str = ""
    sketches: List[Dict[str, Any]] = field(default_factory=list)
    resources: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    build_options: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict) -> "PPAKManifest":
        return cls(
            name=data.get("name", "unnamed"),
            version=data.get("version", "1.0.0"),
            author=data.get("author", ""),
            description=data.get("description", ""),
            sketches=data.get("sketches", []),
            resources=data.get("resources", []),
            dependencies=data.get("dependencies", []),
            build_options=data.get("build_options", {}),
        )

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "version": self.version,
            "author": self.author,
            "description": self.description,
            "sketches": self.sketches,
            "resources": self.resources,
            "dependencies": self.dependencies,
            "build_options": self.build_options,
        }


class PPAKError(Exception):
    pass


class PPAKReader:
    def __init__(self, filepath: str):
        self.filepath = filepath
        self.entries: List[PPAKEntry] = []
        self.manifest: Optional[PPAKManifest] = None
        self._file_size = 0
        self._read_header()

    def _read_header(self):
        with open(self.filepath, "rb") as f:
            magic = f.read(4)
            if magic != MAGIC:
                raise PPAKError(f"Invalid PPAK file: {self.filepath}")

            version, entry_count = struct.unpack("<HI", f.read(6))
            if version != VERSION:
                raise PPAKError(f"Unsupported PPAK version: {version}")

            reserved = struct.unpack("<I", f.read(4))[0]

            for _ in range(entry_count):
                offset, size, name_len = struct.unpack("<IIH", f.read(10))
                name = f.read(name_len).decode("utf-8", errors="replace")
                self.entries.append(PPAKEntry(path=name, offset=offset, size=size))

            self._file_size = f.seek(0, 2)

            meta_entry = self.get_entry(PACK_METADATA_FILE)
            if meta_entry:
                self.manifest = PPAKManifest.from_dict(
                    json.loads(self.extract_file(PACK_METADATA_FILE).decode("utf-8"))
                )

    def get_entry(self, path: str) -> Optional[PPAKEntry]:
        for entry in self.entries:
            if entry.path == path:
                return entry
        return None

    def extract_file(self, path: str) -> bytes:
        entry = self.get_entry(path)
        if entry is None:
            raise PPAKError(f"File not found in package: {path}")

        with open(self.filepath, "rb") as f:
            f.seek(entry.offset)
            return f.read(entry.size)

    def extract_all(self, output_dir: str, progress_callback=None) -> List[str]:
        extracted = []
        for i, entry in enumerate(self.entries):
            if progress_callback:
                progress_callback(i + 1, len(self.entries), entry.path)

            out_path = Path(output_dir) / entry.path
            out_path.parent.mkdir(parents=True, exist_ok=True)

            with open(self.filepath, "rb") as f:
                f.seek(entry.offset)
                with open(out_path, "wb") as out:
                    out.write(f.read(entry.size))

            extracted.append(str(out_path))
        return extracted

    def list_contents(self) -> List[Tuple[str, int]]:
        return [(e.path, e.size) for e in self.entries]

    def get_total_size(self) -> int:
        return sum(e.size for e in self.entries)

    def get_file_hash(self, path: str) -> str:
        data = self.extract_file(path)
        return hashlib.sha256(data).hexdigest()


class PPAKWriter:
    def __init__(self, filepath: str, manifest: Optional[PPAKManifest] = None):
        self.filepath = filepath
        self.manifest = manifest
        self.entries: List[Tuple[str, bytes]] = []

    def add_file(self, path: str, data: bytes):
        self.entries.append((path, data))

    def add_directory(
        self, dir_path: str, base_path: str = "", include_hidden: bool = False
    ):
        base_path = base_path or dir_path
        dir_path = Path(dir_path)

        for root, dirs, files in os.walk(dir_path):
            if not include_hidden:
                dirs[:] = [d for d in dirs if not d.startswith(".")]
                files = [f for f in files if not f.startswith(".")]

            for file in files:
                file_path = Path(root) / file
                rel_path = os.path.relpath(file_path, dir_path)
                rel_path = rel_path.replace(os.sep, "/")

                with open(file_path, "rb") as f:
                    self.add_file(rel_path, f.read())

    def add_directory_from_pattern(
        self, dir_path: str, patterns: List[str], base_path: str = ""
    ):
        base_path = base_path or dir_path
        dir_path = Path(dir_path)

        for pattern in patterns:
            for file_path in dir_path.glob(pattern):
                if file_path.is_file():
                    rel_path = os.path.relpath(file_path, dir_path)
                    rel_path = rel_path.replace(os.sep, "/")
                    with open(file_path, "rb") as f:
                        self.add_file(rel_path, f.read())

    def write(self, compress: bool = False):
        if self.manifest:
            meta_data = json.dumps(
                self.manifest.to_dict(), indent=2, ensure_ascii=False
            ).encode("utf-8")
            self.add_file(PACK_METADATA_FILE, meta_data)

        index_size = len(self.entries) * INDEX_ENTRY_SIZE
        for name, _ in self.entries:
            index_size += len(name.encode("utf-8"))

        data_offset = HEADER_SIZE + index_size

        with open(self.filepath, "wb") as f:
            f.write(MAGIC)
            f.write(struct.pack("<HI", VERSION, len(self.entries)))
            f.write(struct.pack("<I", 0))

            index_data_pos = f.tell()
            for _ in range(len(self.entries)):
                f.write(b"\x00" * INDEX_ENTRY_SIZE)

            data_positions = []
            for path, data in self.entries:
                data_positions.append(f.tell())
                if compress:
                    import zlib

                    compressed = zlib.compress(data, level=9)
                    f.write(compressed)
                else:
                    f.write(data)

            f.seek(index_data_pos)
            for (path, data), data_pos in zip(self.entries, data_positions):
                encoded_path = path.encode("utf-8")
                f.write(struct.pack("<IIH", data_pos, len(data), len(encoded_path)))
                f.write(encoded_path)

            f.seek(0, 2)

        self.entries.clear()


def pack_directory(
    source_dir: str,
    output_ppak: str,
    manifest: Optional[PPAKManifest] = None,
    include_hidden: bool = False,
    compress: bool = False,
):
    writer = PPAKWriter(output_ppak, manifest)
    writer.add_directory(source_dir, include_hidden=include_hidden)
    writer.write(compress=compress)


def pack_data_directory(source_dir: str, output_ppak: str, compress: bool = False):
    data_path = os.path.join(source_dir, "data")
    if not os.path.exists(data_path):
        raise PPAKError(f"Data directory not found: {data_path}")

    writer = PPAKWriter(output_ppak, None)
    writer.add_directory(data_path, include_hidden=False)
    writer.write(compress=compress)


def unpack_ppak(ppak_file: str, output_dir: str, force: bool = False):
    if os.path.exists(output_dir) and not force:
        raise PPAKError(f"Output directory already exists: {output_dir}")

    reader = PPAKReader(ppak_file)
    reader.extract_all(output_dir)
    return reader.manifest


def list_ppak(ppak_file: str) -> List[Tuple[str, int]]:
    reader = PPAKReader(ppak_file)
    return reader.list_contents()


def get_ppak_manifest(ppak_file: str) -> Optional[PPAKManifest]:
    reader = PPAKReader(ppak_file)
    return reader.manifest


def create_manifest(
    name: str,
    version: str = "1.0.0",
    author: str = "",
    description: str = "",
    sketches: List[Dict] = None,
    resources: List[str] = None,
    dependencies: List[str] = None,
) -> PPAKManifest:
    return PPAKManifest(
        name=name,
        version=version,
        author=author,
        description=description,
        sketches=sketches or [],
        resources=resources or [],
        dependencies=dependencies or [],
    )


def load_manifest_from_file(filepath: str) -> PPAKManifest:
    with open(filepath, "r", encoding="utf-8") as f:
        return PPAKManifest.from_dict(json.load(f))


def save_manifest(manifest: PPAKManifest, filepath: str):
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(manifest.to_dict(), f, indent=2, ensure_ascii=False)


def verify_ppak(ppak_file: str) -> Tuple[bool, List[str]]:
    errors = []
    try:
        reader = PPAKReader(ppak_file)

        if reader.entries:
            sorted_entries = sorted(reader.entries, key=lambda e: e.offset)

            for i, entry in enumerate(sorted_entries):
                if entry.offset < HEADER_SIZE + len(sorted_entries) * INDEX_ENTRY_SIZE:
                    for e in reader.entries:
                        entry.offset += len(e.path.encode("utf-8"))

                if i > 0:
                    prev = sorted_entries[i - 1]
                    if entry.offset <= prev.offset + prev.size:
                        errors.append(
                            f"Overlapping entries detected: {prev.path} and {entry.path}"
                        )

        return len(errors) == 0, errors
    except Exception as e:
        errors.append(str(e))
        return False, errors


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("PPAK Library - Processing Package Format")
        print("Usage: python ppak_lib.py <command> [args]")
        print("")
        print("Commands:")
        print("  info <file.ppak>           - Show package information")
        print("  list <file.ppak>          - List package contents")
        print("  verify <file.ppak>         - Verify package integrity")
        sys.exit(1)

    cmd = sys.argv[1]
    filepath = sys.argv[2] if len(sys.argv) > 2 else None

    if cmd == "info" and filepath:
        reader = PPAKReader(filepath)
        print(f"Package: {filepath}")
        print(f"Files: {len(reader.entries)}")
        print(f"Total size: {reader.get_total_size()} bytes")
        if reader.manifest:
            print(f"Name: {reader.manifest.name}")
            print(f"Version: {reader.manifest.version}")
            print(f"Author: {reader.manifest.author}")
    elif cmd == "list" and filepath:
        for path, size in list_ppak(filepath):
            print(f"  {size:>8}  {path}")
    elif cmd == "verify" and filepath:
        valid, errors = verify_ppak(filepath)
        if valid:
            print("Package is valid.")
        else:
            print("Package has errors:")
            for err in errors:
                print(f"  - {err}")
    else:
        print("Unknown command or missing argument.")
        sys.exit(1)
