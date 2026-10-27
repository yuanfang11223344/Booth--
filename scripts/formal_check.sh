#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/formal

prove() {
  local label="$1" top="$2" width="$3" extra="$4" timeout="$5"
  local script="read_verilog -formal -sv rtl/*.v formal/comb_equiv.sv; chparam -set WIDTH ${width} ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -verify -prove-asserts -set-def-inputs -timeout ${timeout}"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'SAT proof finished - no model found: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS SAT ${label}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

prove_seq() {
  local label="$1" file="$2" top="$3" width="$4" extra="$5" depth="$6" timeout="$7"
  local script="read_verilog -formal -sv rtl/*.v ${file}; chparam -set WIDTH ${width} ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -verify -prove-asserts -set-def-inputs -timeout ${timeout}"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'SAT proof finished - no model found: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS bounded SAT ${label} depth=${depth}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

cover_seq() {
  local label="$1" file="$2" top="$3" extra="$4" depth="$5" valid="$6"
  local script="read_verilog -formal -sv rtl/*.v ${file}; chparam -set WIDTH 4 ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -set-at ${depth} ${valid} 1 -set-at ${depth} product 241 -show a,b,product,${valid} -timeout 30"
  yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1
  if grep -q 'SAT solving finished - model found' "build/formal/${label}.log"; then
    echo "PASS SAT cover ${label} product=-15"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

prove_focused() {
  local label="$1" file="$2" top="$3" extra="$4" depth="$5" controls="$6"
  local script="read_verilog -formal -sv rtl/*.v ${file}; chparam -set WIDTH 8 ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -set rst 0 ${controls} -verify -prove-asserts -set-def-inputs -timeout 60"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'SAT proof finished - no model found: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS focused bounded SAT ${label} depth=${depth}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

cover_focused() {
  local label="$1" file="$2" top="$3" extra="$4" depth="$5" controls="$6" finish="$7" valid="$8"
  local script="read_verilog -formal -sv rtl/*.v ${file}; chparam -set WIDTH 8 ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -set rst 0 ${controls} -set-at ${finish} ${valid} 1 -set-at ${finish} product 65445 -show a,b,product,${valid} -timeout 30"
  yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1
  if grep -q 'SAT solving finished - model found' "build/formal/${label}.log"; then
    echo "PASS focused SAT cover ${label} product=-91"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

prove_control() {
  local label="$1" top="$2" width="$3" extra="$4" depth="$5"
  local script="read_verilog -formal -sv rtl/*.v formal/control_equiv.sv; chparam -set WIDTH ${width} ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -verify -prove-asserts -set-def-inputs -timeout 30"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'SAT proof finished - no model found: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS bounded control SAT ${label} depth=${depth}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

prove_induct_control() {
  local label="$1" top="$2" width="$3" extra="$4" maxsteps="$5"
  local script="read_verilog -formal -sv rtl/*.v formal/control_equiv.sv; chparam -set WIDTH ${width} ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -tempinduct -seq 1 -maxsteps ${maxsteps} -set-init-zero -verify -prove-asserts -set-def-inputs -timeout 30"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'Induction step proven: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS inductive control SAT ${label}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

prove_induct_data() {
  local label="$1" file="$2" top="$3" width="$4" extra="$5" maxsteps="$6" timeout="$7"
  local script="read_verilog -formal -sv rtl/*.v ${file}; chparam -set WIDTH ${width} ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -tempinduct -seq 1 -maxsteps ${maxsteps} -set-init-zero -verify -prove-asserts -set-def-inputs -timeout ${timeout}"
  if yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1 && grep -q 'Induction step proven: SUCCESS!' "build/formal/${label}.log"; then
    echo "PASS inductive data/control SAT ${label}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

cover_control() {
  local label="$1" top="$2" extra="$3" depth="$4" controls="$5" finish="$6" valid="$7"
  local script="read_verilog -formal -sv rtl/*.v formal/control_equiv.sv; chparam -set WIDTH 32 ${extra} ${top}; prep -top ${top} -flatten; chformal -lower; sat -seq ${depth} -set-init-zero -set rst 0 ${controls} -set-at ${finish} ${valid} 1 -show ${valid} -timeout 30"
  yosys -Q -T -p "$script" > "build/formal/${label}.log" 2>&1
  if grep -q 'SAT solving finished - model found' "build/formal/${label}.log"; then
    echo "PASS SAT control cover ${label}"
  else
    tail -15 "build/formal/${label}.log"
    exit 1
  fi
}

python3 scripts/check_math.py
prove comb_w4 comb_equiv 4 "" 30
prove unsigned_w4 unsigned_equiv 4 "" 30
prove_seq iter_r2_w4 formal/iter_equiv.sv iter_equiv 4 "-set ARCH 2" 12 60
prove_seq iter_r4_w4 formal/iter_equiv.sv iter_equiv 4 "-set ARCH 4" 10 60
prove_seq iter_r8_w4 formal/iter_equiv.sv iter_equiv 4 "-set ARCH 8" 10 60
prove_seq pipe_w4 formal/pipe_equiv.sv pipe_equiv 4 "" 10 60
cover_seq iter_r2_w4_cover_nonzero formal/iter_equiv.sv iter_equiv "-set ARCH 2" 8 done
cover_seq iter_r4_w4_cover_nonzero formal/iter_equiv.sv iter_equiv "-set ARCH 4" 6 done
cover_seq iter_r8_w4_cover_nonzero formal/iter_equiv.sv iter_equiv "-set ARCH 8" 6 done
cover_seq pipe_w4_cover_nonzero formal/pipe_equiv.sv pipe_equiv "" 5 out_valid
prove_control control_r2_w8 iter_control_equiv 8 "-set ARCH 2" 22
prove_control control_r4_w8 iter_control_equiv 8 "-set ARCH 4" 22
prove_control control_r8_w8 iter_control_equiv 8 "-set ARCH 8" 22
prove_control control_pipe_w8 pipe_control_equiv 8 "" 22
prove_induct_control control_r2_w8_induct iter_control_equiv 8 "-set ARCH 2" 20
prove_induct_control control_r4_w8_induct iter_control_equiv 8 "-set ARCH 4" 20
prove_induct_control control_r8_w8_induct iter_control_equiv 8 "-set ARCH 8" 20
prove_induct_control control_pipe_w8_induct pipe_control_equiv 8 "" 20

if [[ "${1:-}" == "--deep" ]]; then
  prove r4_linear_w8 one_equiv 8 "-set ARCH 0" 60
  prove r4_csa_w8 one_equiv 8 "-set ARCH 1" 60
  prove r8_linear_w8 one_equiv 8 "-set ARCH 2" 60
  prove r8_csa_w8 one_equiv 8 "-set ARCH 3" 60
  prove unsigned_w8 unsigned_equiv 8 "" 60
  prove_seq iter_r2_w5 formal/iter_equiv.sv iter_equiv 5 "-set ARCH 2" 14 30
  prove_seq iter_r4_w5 formal/iter_equiv.sv iter_equiv 5 "-set ARCH 4" 10 30
  prove_seq iter_r8_w5 formal/iter_equiv.sv iter_equiv 5 "-set ARCH 8" 10 30
  prove_seq pipe_w5 formal/pipe_equiv.sv pipe_equiv 5 "" 10 30
  prove_seq iter_r2_w8_composed_short formal/iter_equiv.sv iter_equiv 8 "-set ARCH 2 -set REFERENCE 1" 10 60
  prove_seq iter_r4_w8_composed_short formal/iter_equiv.sv iter_equiv 8 "-set ARCH 4 -set REFERENCE 1" 7 60
  prove_seq iter_r8_w8_composed_short formal/iter_equiv.sv iter_equiv 8 "-set ARCH 8 -set REFERENCE 1" 6 60
  prove_seq pipe_w8_composed formal/pipe_equiv.sv pipe_equiv 8 "-set REFERENCE 1" 10 60
  prove_induct_data pipe_w8_composed_induct formal/pipe_equiv.sv pipe_equiv 8 "-set REFERENCE 1" 6 90
  prove_induct_data iter_r4_w8_composed_induct formal/iter_equiv.sv iter_equiv 8 "-set ARCH 4 -set REFERENCE 1" 12 90
  prove_induct_data iter_r8_w8_composed_induct formal/iter_equiv.sv iter_equiv 8 "-set ARCH 8 -set REFERENCE 1" 8 90
  prove_focused iter_r2_w8_focused formal/iter_equiv.sv iter_equiv "-set ARCH 2" 10 "-set-at 1 start 1"
  prove_focused iter_r4_w8_focused formal/iter_equiv.sv iter_equiv "-set ARCH 4" 7 "-set-at 1 start 1"
  prove_focused iter_r8_w8_focused formal/iter_equiv.sv iter_equiv "-set ARCH 8" 6 "-set-at 1 start 1"
  prove_focused pipe_w8_focused formal/pipe_equiv.sv pipe_equiv "" 4 "-set-at 1 in_valid 1 -set-at 2 in_valid 0 -set-at 3 in_valid 0"
  cover_focused iter_r2_w8_focused_cover formal/iter_equiv.sv iter_equiv "-set ARCH 2" 10 "-set-at 1 start 1" 10 done
  cover_focused iter_r4_w8_focused_cover formal/iter_equiv.sv iter_equiv "-set ARCH 4" 7 "-set-at 1 start 1" 6 done
  cover_focused iter_r8_w8_focused_cover formal/iter_equiv.sv iter_equiv "-set ARCH 8" 6 "-set-at 1 start 1" 5 done
  cover_focused pipe_w8_focused_cover formal/pipe_equiv.sv pipe_equiv "" 4 "-set-at 1 in_valid 1 -set-at 2 in_valid 0" 3 out_valid
  prove_control control_r2_w32 iter_control_equiv 32 "-set ARCH 2" 70
  prove_control control_r4_w32 iter_control_equiv 32 "-set ARCH 4" 70
  prove_control control_r8_w32 iter_control_equiv 32 "-set ARCH 8" 70
  prove_control control_pipe_w32 pipe_control_equiv 32 "" 70
  prove_induct_control control_r2_w32_induct iter_control_equiv 32 "-set ARCH 2" 70
  prove_induct_control control_r4_w32_induct iter_control_equiv 32 "-set ARCH 4" 70
  prove_induct_control control_r8_w32_induct iter_control_equiv 32 "-set ARCH 8" 70
  prove_induct_control control_pipe_w32_induct pipe_control_equiv 32 "" 70
  cover_control control_r2_w32_cover iter_control_equiv "-set ARCH 2" 34 "-set-at 1 start 1" 34 done
  cover_control control_r4_w32_cover iter_control_equiv "-set ARCH 4" 18 "-set-at 1 start 1" 18 done
  cover_control control_r8_w32_cover iter_control_equiv "-set ARCH 8" 14 "-set-at 1 start 1" 13 done
  cover_control control_pipe_w32_cover pipe_control_equiv "" 3 "-set-at 1 in_valid 1" 3 out_valid
fi

# This induction reaches length 17 and can take many hours. Run it deliberately
# after the ordinary deep suite; the standalone log remains independently
# reproducible without slowing every routine verification.
if [[ "${1:-}" == "--induct-r2-w8" ]]; then
  prove r4_csa_w8 one_equiv 8 "-set ARCH 1" 60
  prove_induct_data iter_r2_w8_composed_induct formal/iter_equiv.sv iter_equiv 8 "-set ARCH 2 -set REFERENCE 1" 20 90
fi
