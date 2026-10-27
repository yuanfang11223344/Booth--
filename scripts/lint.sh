#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tops=(
  booth_radix2_iter booth_radix4_iter booth_radix8_iter
  booth_radix4_parallel booth_radix4_csa
  booth_radix8_parallel booth_radix8_csa
  booth_radix4_pipe booth_radix4_unsigned
)
for width in 2 3 5 8 16 32; do
  for top in "${tops[@]}"; do
    verilator --lint-only -Wall -GWIDTH="$width" --top-module "$top" rtl/*.v >/dev/null
  done
done
sources=(
  tb/tb_equivalence.sv tb/tb_unsigned.sv tb/tb_control.sv
  tb/tb_pipeline.sv tb/tb_trace.sv
  formal/comb_equiv.sv formal/comb_equiv.sv formal/comb_equiv.sv
  formal/control_equiv.sv formal/control_equiv.sv
  formal/iter_equiv.sv formal/pipe_equiv.sv
)
checks=(
  tb_equivalence tb_unsigned tb_control tb_pipeline tb_trace
  comb_equiv unsigned_equiv one_equiv
  iter_control_equiv pipe_control_equiv iter_equiv pipe_equiv
)
for index in "${!checks[@]}"; do
  verilator --lint-only --timing -Irtl -Wno-TIMESCALEMOD \
    --top-module "${checks[$index]}" "${sources[$index]}" >/dev/null
done
echo "PASS 54 parameterized RTL elaborations and 12 test/formal tops"
