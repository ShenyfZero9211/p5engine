#!/usr/bin/env python3
"""
PPAK Pack - Pack a directory into a .ppak file

Usage:
    python ppak_pack.py <source_dir> [output.ppak] [options]

Options:
    --manifest <file>    Use manifest file for metadata
    --compress          Compress file data
    --include-hidden    Include hidden files/directories
    --name <name>       Package name
    --version <ver>     Package version
    --author <author>   Package author

Examples:
    python ppak_pack.py my_sketch/
    python ppak_pack.py my_sketch/ my_sketch.ppak
    python ppak_pack.py my_sketch/ --manifest manifest.json --compress
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
    load_manifest_from_file,
    create_manifest,
)


def main():
    parser = argparse.ArgumentParser(
        description="Pack a directory into a .ppak package file"
    )
    parser.add_argument("source_dir", help="Source directory to pack")
    parser.add_argument("output", nargs="?", help="Output .ppak file path")
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

    source_dir = Path(args.source_dir)
    if not source_dir.exists() or not source_dir.is_dir():
        print(f"Error: Source directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_ppak = args.output
    else:
        output_ppak = str(source_dir.with_suffix(".ppak"))

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

    print(f"Packing: {source_dir}")
    print(f"Output:  {output_ppak}")

    pack_directory(
        str(source_dir),
        output_ppak,
        manifest=manifest,
        include_hidden=args.include_hidden,
        compress=args.compress,
    )

    size = os.path.getsize(output_ppak)
    print(f"Done! Created {output_ppak} ({size} bytes)")


if __name__ == "__main__":
    main()
