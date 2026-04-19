#!/usr/bin/env python3
"""
PPAK Unpack - Extract a .ppak file to a directory

Usage:
    python ppak_unpack.py <file.ppak> [output_dir] [options]

Options:
    --force         Overwrite existing directory
    --list-only     Only list contents, don't extract

Examples:
    python ppak_unpack.py my_sketch.ppak
    python ppak_unpack.py my_sketch.ppak extracted/
    python ppak_unpack.py my_sketch.ppak --force
"""

import sys
import os
import argparse
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ppak_lib import PPAKReader, unpack_ppak, PPAKError


def progress_callback(current, total, filename):
    bar_width = 30
    filled = int(bar_width * current / total)
    bar = "=" * filled + "-" * (bar_width - filled)
    percent = current / total * 100
    print(f"\r  [{bar}] {percent:.1f}%  {filename}", end="", flush=True)
    if current == total:
        print()


def main():
    parser = argparse.ArgumentParser(description="Extract a .ppak package file")
    parser.add_argument("ppak_file", help=".ppak file to extract")
    parser.add_argument(
        "output_dir", nargs="?", help="Output directory (default: <name>_unpacked)"
    )
    parser.add_argument(
        "--force", "-f", action="store_true", help="Overwrite existing directory"
    )
    parser.add_argument(
        "--list-only", "-l", action="store_true", help="Only list contents"
    )

    args = parser.parse_args()

    if not os.path.exists(args.ppak_file):
        print(f"Error: File not found: {args.ppak_file}", file=sys.stderr)
        sys.exit(1)

    reader = PPAKReader(args.ppak_file)
    entries = reader.list_contents()

    if args.list_only:
        print(f"Contents of {args.ppak_file}:")
        for path, size in entries:
            print(f"  {size:>8}  {path}")
        print(f"\n{len(entries)} files total")
        return

    if args.output_dir:
        output_dir = args.output_dir
    else:
        name = Path(args.ppak_file).stem
        output_dir = f"{name}_unpacked"

    if os.path.exists(output_dir) and not args.force:
        print(f"Error: Output directory already exists: {output_dir}")
        print("Use --force to overwrite.", file=sys.stderr)
        sys.exit(1)

    print(f"Extracting {len(entries)} files to: {output_dir}/")

    try:
        manifest = unpack_ppak(args.ppak_file, output_dir, force=args.force)
        if manifest:
            print(f"\nPackage: {manifest.name} v{manifest.version}")
            if manifest.author:
                print(f"Author:  {manifest.author}")
            if manifest.description:
                print(f"Desc:    {manifest.description}")
        print(f"\nDone! Extracted to {output_dir}/")
    except PPAKError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
