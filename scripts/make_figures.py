#!/usr/bin/env python3
"""Generate two source-controlled teaching figures; needs matplotlib."""
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets"
OUT.mkdir(exist_ok=True)


def box(ax, xy, text, color, width=2.1, height=0.7):
    x, y = xy
    patch = FancyBboxPatch(
        (x, y), width, height,
        boxstyle="round,pad=0.08,rounding_size=0.12",
        facecolor=color, edgecolor="#263238", linewidth=1.2,
    )
    ax.add_patch(patch)
    ax.text(x + width / 2, y + height / 2, text, ha="center", va="center", fontsize=10)


def arrow(ax, x1, y1, x2, y2):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=12,
                                 linewidth=1.5, color="#455a64"))


fig, ax = plt.subplots(figsize=(12, 5.2))
ax.set_xlim(0, 12)
ax.set_ylim(0, 5.2)
ax.axis("off")
ax.text(6, 4.8, "Booth multiplier architecture map", ha="center", fontsize=16, weight="bold")
box(ax, (0.3, 2.55), "M, Q\n(two's complement)", "#e3f2fd")
box(ax, (3.2, 3.55), "Radix-2 pair\ndecode", "#fff3e0")
box(ax, (6.3, 3.55), "Add / subtract\n+ arithmetic shift", "#e8f5e9", 2.55)
box(ax, (9.45, 3.55), "Product after\nW cycles", "#f3e5f5", 2.2)
box(ax, (3.2, 1.05), "Radix-4/8\nrecode", "#fff3e0")
box(ax, (6.3, 1.05), "Partial product\nrows", "#e8f5e9", 2.55)
box(ax, (9.45, 1.55), "Radix-4 serial\nceil(W/2) cycles", "#f3e5f5", 2.2)
box(ax, (9.45, 0.35), "Parallel add/CSA\ncombinational", "#f3e5f5", 2.2)
arrow(ax, 2.55, 3.2, 3.1, 3.9)
arrow(ax, 5.45, 3.9, 6.2, 3.9)
arrow(ax, 8.95, 3.9, 9.35, 3.9)
arrow(ax, 2.55, 2.9, 3.1, 1.45)
arrow(ax, 5.45, 1.45, 6.2, 1.45)
arrow(ax, 8.95, 1.45, 9.35, 1.9)
arrow(ax, 8.95, 1.4, 9.35, 0.75)
fig.tight_layout()
fig.savefig(OUT / "architecture.png", dpi=180, bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(9, 4.6))
ax.axis("off")
ax.text(0.5, 0.93, "13 x (-7): radix-4 recoding", ha="center", fontsize=16, weight="bold",
        transform=ax.transAxes)
columns = ["k", "bits (y2k+1 y2k y2k-1)", "digit", "13 x digit x 4^k"]
data = [
    ["0", "010", "+1", "+13"],
    ["1", "100", "-2", "-104"],
    ["2", "111", "0", "0"],
    ["3", "111", "0", "0"],
    ["sum", "", "", "-91"],
]
table = ax.table(cellText=data, colLabels=columns, cellLoc="center", loc="center",
                 colWidths=[0.08, 0.44, 0.14, 0.30])
table.auto_set_font_size(False)
table.set_fontsize(11)
table.scale(1, 2.0)
for col in range(4):
    table[(0, col)].set_facecolor("#bbdefb")
    table[(5, col)].set_facecolor("#c8e6c9")
fig.savefig(OUT / "radix4_13x-7.png", dpi=180, bbox_inches="tight")
plt.close(fig)

print("Generated assets/architecture.png and assets/radix4_13x-7.png")
