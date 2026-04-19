#!/usr/bin/env python3
"""
PPAK CLI - Processing Package CLI Tool

Integrated CLI for managing and running Processing sketches from .ppak packages.

Usage:
    python ppak_cli.py <command> [options]

Commands:
    run <sketch>       Build and run a sketch
    build <sketch>     Build a sketch (compile only)
    export <sketch>    Export a sketch as standalone application
    list               List available sketches in package
    init <name>        Initialize a new sketch package

Options:
    --sketch <name>    Sketch name within package
    --output <dir>     Output directory
    --force            Overwrite existing output
    --keep-temp        Keep temporary extracted files
    --timeout <sec>    Timeout for run command

Processing CLI Options:
    --present          Run in presentation mode
    --exported         Use exported mode

Examples:
    python ppak_cli.py list my_project.ppak
    python ppak_cli.py run my_project.ppak --sketch mouse_glitch
    python ppak_cli.py build my_project.ppak --sketch mouse_glitch --output ./build
    python ppak_cli.py export my_project.ppak --sketch mouse_glitch --output ./dist
"""

import sys
import os
import argparse
import tempfile
import shutil
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ppak_lib import (
    PPAKReader,
    PPAKManifest,
    PPAKError,
    unpack_ppak,
    load_manifest_from_file,
    create_manifest,
    pack_data_directory,
)

PROCESSING_CLI = r"D:\Processing\Processing.exe"
TEMP_BASE = tempfile.gettempdir()


def find_pde_file(directory: str) -> Optional[str]:
    for file in os.listdir(directory):
        if file.endswith(".pde"):
            return os.path.join(directory, file)
    return None


def run_processing_cli(
    sketch_path: str,
    output_path: str,
    command: str,
    force: bool = False,
    timeout: int = 0,
) -> int:
    cmd = [
        PROCESSING_CLI,
        "cli",
        f"--sketch={sketch_path}",
        f"--output={output_path}",
    ]

    if force:
        cmd.append("--force")

    cmd.append(command)

    print(f"Running: {' '.join(cmd)}")

    if timeout > 0:
        result = subprocess.run(cmd, timeout=timeout)
    else:
        result = subprocess.run(cmd)

    return result.returncode


def cmd_list(ppak_file: str, manifest: Optional[PPAKManifest]):
    reader = PPAKReader(ppak_file)
    entries = reader.list_contents()

    sketches = []
    for path, size in entries:
        if path.endswith(".pde") and "/" not in path and "\\" not in path:
            sketches.append((path, size))
        elif ".pde" in path and path.endswith(".pde"):
            parts = path.replace("\\", "/").split("/")
            if len(parts) == 2 and parts[1].endswith(".pde"):
                sketches.append((parts[1], size))

    print(f"Available sketches in {os.path.basename(ppak_file)}:")
    if sketches:
        for name, size in sketches:
            print(f"  - {name}")
    else:
        print("  (none found)")

    if manifest and manifest.sketches:
        print(f"\nDefined in manifest:")
        for sketch in manifest.sketches:
            print(f"  - {sketch.get('name', 'unnamed')}")
            print(f"    Entry: {sketch.get('entry', 'N/A')}")
            if sketch.get("resources"):
                print(f"    Resources: {', '.join(sketch.get('resources', []))}")

    print(f"\nTotal: {len(sketches)} sketch(es)")


def cmd_run(
    ppak_file: str,
    sketch_name: Optional[str],
    output_dir: Optional[str],
    force: bool = False,
    keep_temp: bool = False,
    timeout: int = 60,
    present: bool = False,
):
    reader = PPAKReader(ppak_file)
    manifest = reader.manifest

    resolved_sketch_name = sketch_name
    if not resolved_sketch_name and manifest and manifest.sketches:
        resolved_sketch_name = manifest.sketches[0].get("name", "sketch")

    if output_dir:
        sketch_subdir = output_dir
        temp_dir_obj = None
    else:
        temp_dir_obj = tempfile.mkdtemp(prefix="ppak_run_")
        sketch_subdir = os.path.join(
            temp_dir_obj, resolved_sketch_name if resolved_sketch_name else "sketch"
        )
        os.makedirs(sketch_subdir, exist_ok=True)

    try:
        print(f"Extracting to: {sketch_subdir}")
        reader.extract_all(sketch_subdir)

        sketch_path = None
        if sketch_name:
            candidate = os.path.join(sketch_subdir, f"{sketch_name}.pde")
            if os.path.exists(candidate):
                sketch_path = candidate

        if not sketch_path:
            for root, dirs, files in os.walk(sketch_subdir):
                for f in files:
                    if f.endswith(".pde"):
                        sketch_path = os.path.join(root, f)
                        break
                if sketch_path:
                    break

        if not sketch_path or not os.path.exists(sketch_path):
            print(
                f"Error: Sketch not found: {sketch_name or 'default .pde file'}",
                file=sys.stderr,
            )
            sys.exit(1)

        sketch_dir = os.path.dirname(sketch_path)

        build_output = os.path.join(sketch_subdir, "build")

        cmd = "present" if present else "run"
        exit_code = run_processing_cli(
            sketch_dir,
            build_output,
            f"--{cmd}",
            force=force,
            timeout=timeout if not present else 0,
        )

        if exit_code != 0:
            print(f"Processing exited with code {exit_code}")
            sys.exit(exit_code)

    finally:
        if temp_dir_obj and not keep_temp:
            print(f"Cleaning up temporary files...")
            shutil.rmtree(temp_dir_obj, ignore_errors=True)
        elif temp_dir_obj and keep_temp:
            print(f"Temporary files kept at: {temp_dir_obj}")


def cmd_build(
    ppak_file: str,
    sketch_name: Optional[str],
    output_dir: Optional[str],
    force: bool = False,
    keep_temp: bool = False,
):
    reader = PPAKReader(ppak_file)
    manifest = reader.manifest

    resolved_sketch_name = sketch_name
    if not resolved_sketch_name and manifest and manifest.sketches:
        resolved_sketch_name = manifest.sketches[0].get("name", "sketch")

    temp_dir_obj = tempfile.mkdtemp(prefix="ppak_build_")
    sketch_subdir = os.path.join(
        temp_dir_obj, resolved_sketch_name if resolved_sketch_name else "sketch"
    )
    os.makedirs(sketch_subdir, exist_ok=True)

    if not output_dir:
        output_dir = os.path.join(
            os.path.dirname(ppak_file),
            "build",
            resolved_sketch_name if resolved_sketch_name else "sketch",
        )

    try:
        print(f"Extracting to: {sketch_subdir}")
        reader.extract_all(sketch_subdir)

        sketch_path = None
        candidate = os.path.join(sketch_subdir, f"{resolved_sketch_name}.pde")
        if os.path.exists(candidate):
            sketch_path = candidate

        if not sketch_path:
            for root, dirs, files in os.walk(sketch_subdir):
                for f in files:
                    if f.endswith(".pde"):
                        sketch_path = os.path.join(root, f)
                        break
                if sketch_path:
                    break

        if not sketch_path or not os.path.exists(sketch_path):
            print(
                f"Error: Sketch not found: {sketch_name or 'default .pde file'}",
                file=sys.stderr,
            )
            sys.exit(1)

        sketch_dir = os.path.dirname(sketch_path)
        build_output = output_dir

        exit_code = run_processing_cli(sketch_dir, build_output, "--build", force=force)

        if exit_code == 0:
            print(f"Build successful! Output: {build_output}")
        else:
            print(f"Build failed with code {exit_code}")
            sys.exit(exit_code)

    finally:
        if not keep_temp:
            print(f"Cleaning up...")
            shutil.rmtree(temp_dir_obj, ignore_errors=True)
        else:
            print(f"Temporary files kept at: {temp_dir_obj}")


def cmd_export(
    ppak_file: str,
    sketch_name: Optional[str],
    output_dir: Optional[str],
    force: bool = False,
    keep_temp: bool = False,
):
    reader = PPAKReader(ppak_file)
    manifest = reader.manifest

    resolved_sketch_name = sketch_name
    if not resolved_sketch_name and manifest and manifest.sketches:
        resolved_sketch_name = manifest.sketches[0].get("name", "sketch")

    temp_dir_obj = tempfile.mkdtemp(prefix="ppak_export_")
    sketch_subdir = os.path.join(
        temp_dir_obj, resolved_sketch_name if resolved_sketch_name else "sketch"
    )
    os.makedirs(sketch_subdir, exist_ok=True)

    if not output_dir:
        base = os.path.splitext(os.path.basename(ppak_file))[0]
        output_dir = os.path.join(os.path.dirname(ppak_file), "dist", base)

    try:
        print(f"Extracting to: {sketch_subdir}")
        reader.extract_all(sketch_subdir)

        sketch_path = None
        candidate = os.path.join(sketch_subdir, f"{resolved_sketch_name}.pde")
        if os.path.exists(candidate):
            sketch_path = candidate

        if not sketch_path:
            for root, dirs, files in os.walk(sketch_subdir):
                for f in files:
                    if f.endswith(".pde"):
                        sketch_path = os.path.join(root, f)
                        break
                if sketch_path:
                    break

        if not sketch_path or not os.path.exists(sketch_path):
            print(
                f"Error: Sketch not found: {sketch_name or 'default .pde file'}",
                file=sys.stderr,
            )
            sys.exit(1)

        sketch_dir = os.path.dirname(sketch_path)
        build_output = output_dir

        exit_code = run_processing_cli(
            sketch_dir, build_output, "--export", force=force
        )

        if exit_code == 0:
            print(f"Export successful! Output: {build_output}")

            data_ppak_path = os.path.join(build_output, "data.ppak")
            print(f"Creating data.ppak from resources...")
            pack_data_directory(sketch_subdir, data_ppak_path)

            data_src = os.path.join(sketch_subdir, "data")
            if os.path.exists(data_src):
                shutil.rmtree(data_src, ignore_errors=True)

            data_dist = os.path.join(build_output, "data")
            if os.path.exists(data_dist):
                shutil.rmtree(data_dist, ignore_errors=True)
                print(f"Removed exported data folder (resources in data.ppak)")

            print(f"data.ppak created: {os.path.getsize(data_ppak_path)} bytes")
        else:
            print(f"Export failed with code {exit_code}")
            sys.exit(exit_code)

    finally:
        if not keep_temp:
            print(f"Cleaning up...")
            shutil.rmtree(temp_dir_obj, ignore_errors=True)
        else:
            print(f"Temporary files kept at: {temp_dir_obj}")


def cmd_init(name: str, output_dir: Optional[str] = None):
    if not output_dir:
        output_dir = name

    os.makedirs(output_dir, exist_ok=True)

    sketch_dir = os.path.join(output_dir, name)
    os.makedirs(sketch_dir, exist_ok=True)

    resources_dir = os.path.join(sketch_dir, "resources")
    os.makedirs(resources_dir, exist_ok=True)

    shaders_dir = os.path.join(resources_dir, "shaders")
    os.makedirs(shaders_dir, exist_ok=True)

    data_dir = os.path.join(resources_dir, "data")
    os.makedirs(data_dir, exist_ok=True)

    main_pde = os.path.join(sketch_dir, f"{name}.pde")
    with open(main_pde, "w", encoding="utf-8") as f:
        f.write(f"""void setup() {{
  size(800, 600);
  // Your setup code here
}}

void draw() {{
  // Your draw code here
}}
""")

    manifest = create_manifest(
        name=name, version="1.0.0", description=f"Processing sketch: {name}"
    )
    manifest.sketches = [
        {"name": name, "entry": f"{name}.pde", "resources": ["resources/*"]}
    ]

    manifest_path = os.path.join(output_dir, "manifest.json")
    from ppak_lib import save_manifest

    save_manifest(manifest, manifest_path)

    readme = os.path.join(output_dir, "README.md")
    with open(readme, "w", encoding="utf-8") as f:
        f.write(f"""# {name}

Processing sketch package.

## Structure

```
{name}/
├── manifest.json    # Package manifest
├── {name}.pde        # Main sketch file
└── resources/        # Resources (shaders, data, etc.)
    ├── shaders/
    └── data/
```

## Commands

```bash
# Pack
python ../tools/ppak/ppak_pack.py {name}/ --manifest manifest.json

# Run
python ../tools/ppak/ppak_cli.py run {name}.ppak --sketch {name}

# Build
python ../tools/ppak/ppak_cli.py build {name}.ppak --sketch {name} --output ./build

# Export
python ../tools/ppak/ppak_cli.py export {name}.ppak --sketch {name} --output ./dist
```
""")

    print(f"Initialized sketch package at: {output_dir}/")
    print(f"  - {name}.pde (main sketch)")
    print(f"  - resources/shaders/")
    print(f"  - resources/data/")
    print(f"  - manifest.json")
    print(f"  - README.md")


def main():
    parser = argparse.ArgumentParser(
        description="PPAK CLI - Processing Package CLI Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s list sketch.ppak
  %(prog)s run sketch.ppak --sketch my_sketch
  %(prog)s build sketch.ppak --sketch my_sketch --output ./build
  %(prog)s export sketch.ppak --sketch my_sketch --output ./dist
  %(prog)s init my_new_sketch
        """,
    )
    parser.add_argument(
        "command",
        choices=["list", "run", "build", "export", "init"],
        help="Command to execute",
    )
    parser.add_argument(
        "target", nargs="?", help="Package file or sketch name (for init)"
    )
    parser.add_argument("--sketch", "-s", help="Sketch name within package")
    parser.add_argument("--output", "-o", help="Output directory")
    parser.add_argument("--force", "-f", action="store_true", help="Force overwrite")
    parser.add_argument("--keep-temp", action="store_true", help="Keep temporary files")
    parser.add_argument(
        "--timeout", "-t", type=int, default=60, help="Timeout in seconds"
    )
    parser.add_argument(
        "--present", "-p", action="store_true", help="Presentation mode"
    )

    args = parser.parse_args()

    if args.command == "init":
        if not args.target:
            print("Error: init requires a sketch name", file=sys.stderr)
            sys.exit(1)
        cmd_init(args.target, args.output)
        return

    if not args.target:
        print("Error: Package file required", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    if not os.path.exists(args.target):
        print(f"Error: File not found: {args.target}", file=sys.stderr)
        sys.exit(1)

    reader = PPAKReader(args.target)
    manifest = reader.manifest

    if args.command == "list":
        cmd_list(args.target, manifest)
    elif args.command == "run":
        cmd_run(
            args.target,
            args.sketch,
            args.output,
            args.force,
            args.keep_temp,
            args.timeout,
            args.present,
        )
    elif args.command == "build":
        cmd_build(args.target, args.sketch, args.output, args.force, args.keep_temp)
    elif args.command == "export":
        cmd_export(args.target, args.sketch, args.output, args.force, args.keep_temp)


if __name__ == "__main__":
    main()
