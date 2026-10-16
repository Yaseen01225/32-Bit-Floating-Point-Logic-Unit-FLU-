# Floating-Point Logic Unit (FLU) — Verilog HDL

## Features
A modular 32-bit floating-point arithmetic project with add, subtract, multiply,
and divide operations. The top-level selector uses `operation` codes:
`00` add, `01` subtract, `10` multiply, `11` divide. Division also raises
`divide_by_zero` when operand B is zero.

## Files
- `rtl/flu_top.v` — top-level operation selector
- `rtl/fp32_add_sub.v` — addition and subtraction
- `rtl/fp32_mul.v` — multiplication
- `rtl/fp32_div.v` — division and divide-by-zero indication
- `tb/tb_flu_top.v` — simulation testbench

## Vivado setup
1. Create a new RTL project in Xilinx Vivado.
2. Add all files in `rtl/` as Design Sources.
3. Add `tb/tb_flu_top.v` as a Simulation Source.
4. Set `tb_flu_top` as the simulation top and run Behavioral Simulation.
5. Inspect the transcript and waveforms for the five test vectors.

## Header metadata
Each Verilog source has a project header with purpose, developer, date, and
platform. Replace “Replace with your name” with your own name before submission.

## Important limitations
This is an educational baseline, not a fully IEEE-754-compliant production core.
It primarily demonstrates sign/exponent/significand datapaths for normalized
finite values. Full support for subnormal numbers, NaNs, infinities, signed-zero
rules, guard/round/sticky bits, selectable rounding modes, and all exception
flags is not implemented. The divider uses `/`, which can infer a large
combinational divider. Verify and extend the design before hardware deployment.

## Project metadata
Developer: Ghulam Yaseen Nangraj
Date: 2026-10-16
Platform: Xilinx Vivado / Verilog HDL
