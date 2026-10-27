#!/usr/bin/env python3
"""Read the project's VCD and make a cycle CSV and annotated waveform PNG.

This small parser intentionally reads only standard scalar/vector VCD changes.
It is not a general-purpose VCD library. No external waveform plugin is needed.
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
SIGNALS = [
    "tb_trace.clk", "tb_trace.start", "tb_trace.r2.a_reg", "tb_trace.r2.q_reg",
    "tb_trace.r2.q_minus", "tb_trace.r2.count", "tb_trace.r2.done",
    "tb_trace.r4i.accumulator", "tb_trace.r4i.count", "tb_trace.r4i.done",
    "tb_trace.r8i.accumulator", "tb_trace.r8i.count", "tb_trace.r8i.done",
    "tb_trace.p_r2", "tb_trace.p_r4i",
    "tb_trace.p_r8i",
    "tb_trace.pipe_r4.valid_reg",
    "tb_trace.valid_pipe", "tb_trace.p_pipe",
]


def as_int(bits: str | None, signed=False):
    if bits is None or any(c in bits.lower() for c in "xz"):
        return None
    val = int(bits, 2)
    if signed and bits[0] == "1":
        val -= 1 << len(bits)
    return val


def read_vcd(path: Path):
    scopes = []
    wanted_ids = {}
    widths = {}
    values = {}
    samples = []
    t = None
    pending = False

    def flush():
        nonlocal pending
        if pending and t is not None:
            sample = {"time_ps": t}
            for name in SIGNALS:
                sample[name] = values.get(wanted_ids.get(name, ""))
            samples.append(sample)
        pending = False

    with path.open() as fh:
        header = True
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if header:
                words = line.split()
                if words[0] == "$scope":
                    scopes.append(words[2])
                elif words[0] == "$upscope":
                    scopes.pop()
                elif words[0] == "$var":
                    full_name = ".".join(scopes + [words[4]])
                    if full_name in SIGNALS:
                        wanted_ids[full_name] = words[3]
                        widths[words[3]] = int(words[2])
                elif words[0] == "$enddefinitions":
                    header = False
                continue
            if line.startswith("#"):
                flush()
                t = int(line[1:])
            elif line[0] in "bB":
                bits, ident = line[1:].split()
                bits = bits.lower()
                values[ident] = bits.rjust(widths.get(ident, len(bits)),
                                            bits[0] if bits[0] in "xz" else "0")
            elif line[0] in "01xXzZ":
                values[line[1:]] = line[0].lower()
            # Ignore $dumpvars/$end and real/string changes.
            if wanted_ids.get("tb_trace.clk") in values and line == "1" + wanted_ids["tb_trace.clk"]:
                pending = True
    flush()
    missing = set(SIGNALS) - set(wanted_ids)
    if missing:
        raise ValueError(f"Missing VCD signals: {sorted(missing)}")
    return samples


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("vcd", type=Path, nargs="?", default=ROOT / "build/trace_13x-7.vcd")
    args = parser.parse_args()
    rows = read_vcd(args.vcd)
    out = args.vcd.with_suffix("")
    csv_path = out.with_name(out.name + "_cycles.csv")
    png_path = out.with_name(out.name + "_waveform.png")
    pipeline_path = out.with_name(out.name + "_pipeline.png")
    labels = ["time_ns", "radix2_A", "radix2_Q_hex", "radix2_qminus",
              "radix2_count", "radix2_done", "radix4_accumulator", "radix4_count",
              "radix4_done", "radix2_product", "radix4_product",
              "start", "pipe_stage_valid", "pipe_out_valid", "pipe_product",
              "radix8_accumulator", "radix8_count", "radix8_done", "radix8_product"]
    data = []
    for row in rows:
        q_bits = row["tb_trace.r2.q_reg"]
        data.append([
            row["time_ps"] / 1000,
            as_int(row["tb_trace.r2.a_reg"], True),
            None if as_int(q_bits) is None else f"0x{as_int(q_bits):X}",
            as_int(row["tb_trace.r2.q_minus"]),
            as_int(row["tb_trace.r2.count"]),
            as_int(row["tb_trace.r2.done"]),
            as_int(row["tb_trace.r4i.accumulator"], True),
            as_int(row["tb_trace.r4i.count"]),
            as_int(row["tb_trace.r4i.done"]),
            as_int(row["tb_trace.p_r2"], True),
            as_int(row["tb_trace.p_r4i"], True),
            as_int(row["tb_trace.start"]),
            as_int(row["tb_trace.pipe_r4.valid_reg"]),
            as_int(row["tb_trace.valid_pipe"]),
            as_int(row["tb_trace.p_pipe"], True),
            as_int(row["tb_trace.r8i.accumulator"], True),
            as_int(row["tb_trace.r8i.count"]),
            as_int(row["tb_trace.r8i.done"]),
            as_int(row["tb_trace.p_r8i"], True),
        ])
    with csv_path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(labels)
        writer.writerows(data)

    fig, axes = plt.subplots(4, 1, figsize=(11, 8), sharex=True)
    x = [r[0] for r in data]
    if not x:
        raise ValueError("VCD has no sampled rising clock edges")
    for ax, col, title, color in [
        (axes[0], 1, "R2 A", "#1976d2"),
        (axes[1], 6, "R4 sum", "#ef6c00"),
        (axes[2], 15, "R8 sum", "#2e7d32"),
    ]:
        y = [r[col] for r in data]
        ax.step(x, y, where="post", color=color, linewidth=2)
        ax.scatter(x[-1], y[-1], color=color, s=18, zorder=3)
        ax.set_ylabel(title)
        ax.grid(alpha=0.3)
    r2_done = [r[5] for r in data]
    r4_done = [r[8] for r in data]
    r8_done = [r[17] for r in data]
    axes[3].step(x, r2_done, where="post", label="radix-2 done", linewidth=2)
    axes[3].step(x, r4_done, where="post", label="radix-4 done", linewidth=2)
    axes[3].step(x, r8_done, where="post", label="radix-8 done", linewidth=2)
    axes[3].scatter(x[-1], r2_done[-1], color="#1976d2", s=30, zorder=3)
    axes[3].set_ylabel("done")
    axes[3].set_xlabel("simulation time (ns)")
    axes[3].set_yticks([0, 1])
    axes[3].grid(alpha=0.3)
    axes[3].legend(loc="upper left")
    fig.suptitle(args.vcd.name + " (sampled at positive clock edges)")
    fig.tight_layout()
    fig.savefig(png_path, dpi=180)
    plt.close(fig)

    fig, axes = plt.subplots(4, 1, figsize=(11, 7), sharex=True)
    for ax, (col, label, color) in zip(axes[:3], [
        (11, "start / in_valid", "#455a64"),
        (12, "stage valid", "#ef6c00"),
        (13, "out_valid", "#1976d2"),
    ]):
        y = [r[col] for r in data]
        ax.step(x, y, where="post", color=color, linewidth=2)
        ax.scatter(x[-1], y[-1], color=color, s=18, zorder=3)
        ax.set_yticks([0, 1])
        ax.set_ylabel(label)
        ax.grid(alpha=0.3)
    pipe_product = [r[14] for r in data]
    axes[3].step(x, pipe_product, where="post", color="#6a1b9a", linewidth=2)
    axes[3].scatter(x[-1], pipe_product[-1], color="#6a1b9a", s=18, zorder=3)
    axes[3].set_ylabel("pipeline product")
    axes[3].set_xlabel("simulation time (ns)")
    axes[3].grid(alpha=0.3)
    fig.suptitle(args.vcd.name + " (pipeline registers sampled after rising edges)")
    fig.tight_layout()
    fig.savefig(pipeline_path, dpi=180)
    plt.close(fig)
    print(f"Generated {csv_path}, {png_path}, and {pipeline_path}")


if __name__ == "__main__":
    main()
