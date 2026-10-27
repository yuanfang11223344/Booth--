#!/usr/bin/env python3
"""Create a portable source-and-evidence archive with UTF-8 filenames."""
from __future__ import annotations

import argparse
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRS = ("rtl", "tb", "formal", "scripts", "docs", "assets", "references")
VIDEO_FILES = (
    "video/Booth编码原理与硬件实现_晓晓女声有声版.mp4",
    "video/讲解词.md",
    "video/Booth编码讲解音频.m4a",
    "video/paper_page1.png",
    "video/paper_page3.png",
)
EVIDENCE_FILES = (
    "build/run_recheck_20261023.log",
    "build/lint_recheck_20261023.log",
    "build/formal/deep_final.log",
    "build/formal/iter_r2_w8_composed_induct.log",
    "build/formal/iter_r8_w8_composed_induct.log",
    "build/formal/r4_csa_w12.log",
    "build/trace_13x-7.vcd",
    "build/trace_13x-7_cycles.csv",
    "build/trace_minx-1.vcd",
    "build/trace_minx-1_cycles.csv",
    "build/synth/summary.csv",
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "output", nargs="?", type=Path,
        default=ROOT.parent / "Booth编码-完整工程-20261023.zip",
    )
    args = parser.parse_args()
    files = [
        ROOT / "README.md", ROOT / "STATUS.md", ROOT / "requirements-video.txt", ROOT / ".gitignore",
        ROOT / ".vscode/settings.json",
    ]
    for directory in SOURCE_DIRS:
        files.extend(
            p for p in (ROOT / directory).rglob("*")
            if p.is_file() and not p.is_symlink()
            and "__pycache__" not in p.parts and p.name != ".DS_Store"
        )
    files.extend(ROOT / item for item in EVIDENCE_FILES + VIDEO_FILES)
    files.extend(p for p in (ROOT / "build/synth").glob("*.json") if p.is_file())
    missing = [str(p) for p in files if not p.is_file()]
    if missing:
        raise SystemExit(f"Missing files: {missing}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(set(files)):
            archive.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(args.output) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f"ZIP integrity failed: {bad}")
        names = set(archive.namelist())
        if "README.md" not in names or "rtl/booth_radix8_iter.v" not in names:
            raise SystemExit("ZIP is missing core source files")
    print(f"Created {args.output} ({len(files)} source and evidence files)")


if __name__ == "__main__":
    main()
