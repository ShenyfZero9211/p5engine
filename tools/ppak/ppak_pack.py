#!/usr/bin/env python3
"""
PPAK Pack - Pack one or more directories into a .ppak file

Usage:
    # Single directory (backward compatible)
    python ppak_pack.py <source_dir> [output.ppak] [options]

    # Multiple directories (uses directory base name as path prefix)
    python ppak_pack.py data/ music/ sounds/ textures/ -o data.ppak

Options:
    -o, --output <file>  Output .ppak file path
    --manifest <file>    Use manifest file for metadata
    --compress           Compress file data
    --include-hidden     Include hidden files/directories
    --name <name>        Package name
    --version <ver>      Package version
    --author <author>    Package author

Examples:
    python ppak_pack.py my_sketch/
    python ppak_pack.py my_sketch/ my_sketch.ppak
    python ppak_pack.py data/ music/ sounds/ -o output.ppak --compress
"""

import sys
import os
import argparse
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ppak_lib import (
    PPAKWriter,
    PPAKManifest,
    pack_directory,
    pack_multi_directory,
    load_manifest_from_file,
    create_manifest,
)


def main():
    parser = argparse.ArgumentParser(
        description="Pack one or more directories into a .ppak package file"
    )
    parser.add_argument(
        "source_dirs",
        nargs="+",
        help="Source directory(s) to pack. If multiple, each dir's base name becomes the path prefix inside the PPAK.",
    )
    parser.add_argument(
        "-o", "--output", help="Output .ppak file path"
    )
    parser.add_argument("--manifest", "-m", help="Manifest JSON file")
    parser.add_argument(
        "--compress", "-c", action="store_true", help="Compress file data"
    )
    parser.add_argument(
        "--include-hidden", action="store_true", help="Include hidden files"
    )
    parser.add_argument("--name", "-n", help="Package name")
    parser.add_argument("--version", "-v", default="1.0.0", help="Package version")
    parser.add_argument("--author", "-a", help="Package author")
    parser.add_argument("--description", "-d", help="Package description")

    args = parser.parse_args()

    # Validate source directories
    valid_dirs = []
    for sd in args.source_dirs:
        p = Path(sd)
        if not p.exists() or not p.is_dir():
            print(f"Error: Source directory not found: {p}", file=sys.stderr)
            sys.exit(1)
        valid_dirs.append(str(p.resolve()))

    # Resolve output path
    if args.output:
        output_ppak = args.output
    elif len(valid_dirs) == 1:
        output_ppak = str(Path(valid_dirs[0]).with_suffix(".ppak"))
    else:
        print("Error: --output is required when packing multiple directories", file=sys.stderr)
        sys.exit(1)

    manifest = None
    if args.manifest:
        manifest = load_manifest_from_file(args.manifest)
    elif args.name:
        manifest = create_manifest(
            name=args.name,
            version=args.version,
            author=args.author or "",
            description=args.description or "",
        )

    print(f"Packing {len(valid_dirs)} director{'y' if len(valid_dirs) == 1 else 'ies'}:")
    for d in valid_dirs:
        prefix = os.path.basename(os.path.normpath(d))
        print(f"  {d}  ->  prefix: {prefix}/")
    print(f"Output:  {output_ppak}")

    if len(valid_dirs) == 1:
        pack_directory(
            valid_dirs[0],
            output_ppak,
            manifest=manifest,
            include_hidden=args.include_hidden,
            compress=args.compress,
        )
    else:
        pack_multi_directory(
            valid_dirs,
            output_ppak,
            manifest=manifest,
            include_hidden=args.include_hidden,
            compress=args.compress,
        )

    size = os.path.getsize(output_ppak)
    print(f"Done! Created {output_ppak} ({size:,} bytes)")


if __name__ == "__main__":
    main()
