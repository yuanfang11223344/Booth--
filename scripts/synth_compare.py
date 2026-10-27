#!/usr/bin/env python3
"""Reproducible generic-gate comparison; no FPGA or ASIC timing claims."""
from __future__ import annotations

import argparse
import collections
import csv
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "synth"
SOURCES = {
    "mul_inferred": ("mul_inferred",),
    "booth_radix2_iter": ("booth_radix2_iter",),
    "booth_radix4_iter": ("booth_radix4_iter",),
    "booth_radix8_iter": ("booth_radix8_iter",),
    "booth_radix4_parallel": ("booth_radix4_pp", "booth_radix4_parallel"),
    "booth_radix4_csa": ("booth_radix4_pp", "csa_reduce", "booth_radix4_csa"),
    "booth_radix8_parallel": ("booth_radix8_pp", "booth_radix8_parallel"),
    "booth_radix8_csa": ("booth_radix8_pp", "csa_reduce", "booth_radix8_csa"),
    "booth_radix4_pipe": ("booth_radix4_pp", "csa_reduce", "booth_radix4_pipe"),
    "booth_radix4_unsigned": (
        "booth_radix4_pp", "csa_reduce", "booth_radix4_csa",
        "booth_radix4_unsigned",
    ),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--widths", nargs="+", type=int, default=[8, 16])
    args = parser.parse_args()
    if any(w < 2 for w in args.widths):
        parser.error("All widths must be at least 2")
    OUT.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output(["yosys", "-V"], text=True).strip()
    rows = []
    for width in args.widths:
        for top, dependencies in SOURCES.items():
            sources = " ".join(f"rtl/{name}.v" for name in dependencies)
            stem = f"{top}_w{width}"
            json_path = OUT / f"{stem}.json"
            log_path = OUT / f"{stem}.log"
            script = (
                f"read_verilog {sources}; "
                f"chparam -set WIDTH {width} {top}; "
                f"synth -top {top} -flatten; "
                f"write_json {json_path.relative_to(ROOT)}; "
                "ltp -noff"
            )
            with log_path.open("w") as log:
                result = subprocess.run(
                    ["yosys", "-Q", "-T", "-p", script],
                    cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                    check=False,
                )
            if result.returncode:
                raise RuntimeError(f"Yosys failed for {stem}; see {log_path}")
            design = json.loads(json_path.read_text())
            cells = collections.Counter(
                item["type"] for item in design["modules"][top]["cells"].values()
                if item["type"] != "$scopeinfo"
            )
            flipflops = sum(count for kind, count in cells.items() if "DFF" in kind)
            total = sum(cells.values())
            match = re.search(
                rf"Longest topological path in {re.escape(top)} \(length=(\d+)\)",
                log_path.read_text(),
            )
            if not match:
                raise RuntimeError(f"No topological path reported for {stem}")
            rows.append({
                "width": width,
                "top": top,
                "generic_logic_cells": total - flipflops,
                "flipflop_bits": flipflops,
                "total_cells": total,
                "longest_topological_path": int(match.group(1)),
                "yosys_version": version,
            })
            print(f"{stem}: logic={total-flipflops}, FF={flipflops}, depth={match.group(1)}")
    csv_path = OUT / "summary.csv"
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {csv_path}")


if __name__ == "__main__":
    main()
