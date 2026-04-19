#!/usr/bin/env python3
"""
PPAK List - List contents of a .ppak file

Usage:
    python ppak_ls.py <file.ppak> [options]

Options:
    --long          Use long format (size, date)
    --details       Show detailed package info
    --grep <pat>    Filter by pattern

Examples:
    python ppak_ls.py my_sketch.ppak
    python ppak_ls.py my_sketch.ppak --details
    python ppak_ls.py my_sketch.ppak --grep ".pde"
"""

import sys
import os
import argparse
import re
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ppak_lib import PPAKReader, PPAKError


def format_size(size: int) -> str:
    if size < 1024:
        return f"{size}B"
    elif size < 1024 * 1024:
        return f"{size / 1024:.1f}KB"
    else:
        return f"{size / (1024 * 1024):.1f}MB"


def main():
    parser = argparse.ArgumentParser(
        description="List contents of a .ppak package file"
    )
    parser.add_argument("ppak_file", help=".ppak file to list")
    parser.add_argument("--long", "-l", action="store_true", help="Long format")
    parser.add_argument(
        "--details", "-d", action="store_true", help="Show package details"
    )
    parser.add_argument("--grep", "-g", help="Filter by pattern (regex)")

    args = parser.parse_args()

    if not os.path.exists(args.ppak_file):
        print(f"Error: File not found: {args.ppak_file}", file=sys.stderr)
        sys.exit(1)

    try:
        reader = PPAKReader(args.ppak_file)
        entries = reader.list_contents()

        if args.grep:
            pattern = re.compile(args.grep, re.IGNORECASE)
            entries = [(p, s) for p, s in entries if pattern.search(p)]

        if args.details or args.long:
            print(f"Package: {args.ppak_file}")
            print(f"Files:   {len(entries)}")
            print(f"Size:    {format_size(reader.get_total_size())}")

            if reader.manifest:
                print(f"Name:    {reader.manifest.name}")
                print(f"Version: {reader.manifest.version}")
                if reader.manifest.author:
                    print(f"Author:  {reader.manifest.author}")
                if reader.manifest.description:
                    print(f"Desc:    {reader.manifest.description}")
                if reader.manifest.sketches:
                    print(f"Sketches:")
                    for sketch in reader.manifest.sketches:
                        print(
                            f"  - {sketch.get('name', 'unnamed')}: {sketch.get('entry', 'N/A')}"
                        )
            print()

        if not entries:
            print("No files found.")
            return

        for path, size in entries:
            if args.long:
                print(f"  {format_size(size):>8}  {path}")
            else:
                print(path)

        if args.long or args.details:
            print(f"\n{len(entries)} file(s)")

    except PPAKError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
