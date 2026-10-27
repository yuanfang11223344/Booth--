#!/usr/bin/env python3
"""Exhaustively check the recoding identities, independent of Verilog RTL."""


def signed_value(raw: int, width: int) -> int:
    return raw - (1 << width) if raw & (1 << (width - 1)) else raw


def recoded_value(raw: int, width: int, radix: int) -> int:
    step = {2: 1, 4: 2, 8: 3}[radix]

    def bit(index: int) -> int:
        if index < 0:
            return 0
        if index >= width:
            return (raw >> (width - 1)) & 1
        return (raw >> index) & 1

    value = 0
    for group in range((width + step - 1) // step):
        base = step * group
        if radix == 2:
            digit = bit(base - 1) - bit(base)
        elif radix == 4:
            digit = bit(base - 1) + bit(base) - 2 * bit(base + 1)
        else:
            digit = (bit(base - 1) + bit(base) + 2 * bit(base + 1)
                     - 4 * bit(base + 2))
        value += digit * (radix**group)
    return value


def main():
    count = 0
    for width in range(2, 17):
        for raw in range(1 << width):
            expected = signed_value(raw, width)
            for radix in (2, 4, 8):
                actual = recoded_value(raw, width, radix)
                if actual != expected:
                    raise AssertionError((width, raw, radix, actual, expected))
            count += 1
    print(f"PASS radix-2/4/8 identities for {count} complete multiplier bit patterns (W=2..16)")


if __name__ == "__main__":
    main()
