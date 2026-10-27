#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rtl=(rtl/*.v)
for width in 2 3 4 5 6 7 8 9 12 16 24 31 32; do
  iverilog -g2012 -Wall -s tb_equivalence -Ptb_equivalence.W="$width" \
    -o "build/equivalence_w${width}.vvp" "${rtl[@]}" tb/tb_equivalence.sv
  vvp "build/equivalence_w${width}.vvp"
done
for width in 2 3 4 5 6 7 8 9 12 16 24 31 32; do
  iverilog -g2012 -Wall -s tb_unsigned -Ptb_unsigned.W="$width" \
    -o "build/unsigned_w${width}.vvp" "${rtl[@]}" tb/tb_unsigned.sv
  vvp "build/unsigned_w${width}.vvp"
done
iverilog -g2012 -Wall -s tb_control -o build/control.vvp "${rtl[@]}" tb/tb_control.sv
vvp build/control.vvp
iverilog -g2012 -Wall -s tb_pipeline -o build/pipeline.vvp "${rtl[@]}" tb/tb_pipeline.sv
vvp build/pipeline.vvp
iverilog -g2012 -Wall -s tb_trace -o build/trace.vvp "${rtl[@]}" tb/tb_trace.sv
vvp build/trace.vvp "+VCD=build/trace_13x-7.vcd" "+A=13" "+B=-7"
