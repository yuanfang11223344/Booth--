#!/usr/bin/env python3
"""Plot generic Yosys statistics without treating cell counts as area."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build" / "synth" / "summary.csv"
LABELS = {
    "mul_inferred": "inferred *",
    "booth_radix2_iter": "radix-2 iterative",
    "booth_radix4_iter": "radix-4 iterative",
    "booth_radix8_iter": "radix-8 iterative",
    "booth_radix4_parallel": "radix-4 linear",
    "booth_radix4_csa": "radix-4 CSA",
    "booth_radix8_parallel": "radix-8 linear",
    "booth_radix8_csa": "radix-8 CSA",
    "booth_radix4_pipe": "radix-4 CSA pipeline",
    "booth_radix4_unsigned": "unsigned wrapper",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--width", type=int, default=16)
    args = parser.parse_args()
    with SOURCE.open() as handle:
        rows = [row for row in csv.DictReader(handle) if int(row["width"]) == args.width]
    if not rows:
        parser.error(f"No W={args.width} entries in {SOURCE}; run synth_compare.py")
    names = [LABELS[row["top"]] for row in rows]
    y = list(range(len(rows)))
    fig, axes = plt.subplots(1, 3, figsize=(15, 5.3), sharey=True)
    specs = [
        ("generic_logic_cells", "Generic logic cells", "#1976d2"),
        ("flipflop_bits", "Flip-flop bits", "#ef6c00"),
        ("longest_topological_path", "Longest topological path", "#2e7d32"),
    ]
    for ax, (key, title, color) in zip(axes, specs):
        vals = [int(row[key]) for row in rows]
        ax.barh(y, vals, color=color, alpha=0.86)
        ax.set_xlabel(title)
        ax.grid(axis="x", alpha=0.25)
        ax.set_axisbelow(True)
        ax.set_xlim(0, max(vals) * 1.16 + 1)
        for index, value in enumerate(vals):
            ax.text(value, index, f" {value}", va="center", fontsize=8)
    axes[0].set_yticks(y, names)
    axes[0].invert_yaxis()
    fig.suptitle(f"Yosys generic mapping, W={args.width} (no target technology library)")
    fig.tight_layout()
    output = ROOT / "assets" / f"synth_w{args.width}.png"
    fig.savefig(output, dpi=170)
    print(f"Generated {output}")


if __name__ == "__main__":
    main()
