#!/usr/bin/env python3
"""Print bit-level Booth recoding independently of the RTL simulator."""
from __future__ import annotations

import argparse


def main():
    parser = argparse.ArgumentParser(description="Explain two's-complement Booth recoding")
    parser.add_argument("width", type=int)
    parser.add_argument("multiplicand", type=int)
    parser.add_argument("multiplier", type=int)
    args = parser.parse_args()
    w, m, q = args.width, args.multiplicand, args.multiplier
    if w < 2 or w > 64:
        parser.error("width must be 2..64")
    low, high = -(1 << (w - 1)), (1 << (w - 1)) - 1
    if not (low <= m <= high and low <= q <= high):
        parser.error(f"both operands must fit signed {w}-bit range [{low}, {high}]")
    raw = q & ((1 << w) - 1)

    def bit(i: int) -> int:
        if i < 0:
            return 0
        if i >= w:
            return (raw >> (w - 1)) & 1
        return (raw >> i) & 1

    print(f"W={w}, M={m}, Q={q} ({raw:0{w}b} two's complement)")
    print(f"Expected product: {m*q} ({m*q & ((1 << (2*w))-1):0{2*w}b})")
    for radix, step, high_weight in [(2, 1, 1), (4, 2, 2), (8, 3, 4)]:
        print(f"\nRadix-{radix}:")
        print(" k  bits   digit  shift  partial_product")
        total = 0
        rows = (w + step - 1) // step
        for k in range(rows):
            base = step * k
            bits = "".join(str(bit(i)) for i in range(base + step - 1, base - 2, -1))
            if radix == 2:
                digit = bit(base - 1) - bit(base)
            elif radix == 4:
                digit = -2 * bit(base + 1) + bit(base) + bit(base - 1)
            else:
                digit = (-4 * bit(base + 2) + 2 * bit(base + 1)
                         + bit(base) + bit(base - 1))
            assert -high_weight <= digit <= high_weight
            pp = m * digit * (radix**k)
            total += pp
            print(f"{k:2d}  {bits:4s}  {digit:+5d}  {base:5d}  {pp:+15d}")
        print(f"sum={total}")
        assert total == m * q


if __name__ == "__main__":
    main()
