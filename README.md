# 32-Bit Floating-Point Logic Unit (FLU) in Verilog HDL

**A Modular Floating-Point Arithmetic Design Using Verilog HDL**

![Language](https://img.shields.io/badge/Language-Verilog%20HDL-blue)
![Data Width](https://img.shields.io/badge/Data%20Width-32--Bit-orange)
![Format](https://img.shields.io/badge/Format-IEEE%20754%20Binary32-green)
![Platform](https://img.shields.io/badge/Platform-Xilinx%20Vivado-red)
![Project Type](https://img.shields.io/badge/Project-Educational-purple)

**Developer:** Ghulam Yaseen Nangraj  
**Development Platform:** Xilinx Vivado 2025.2.1  
**Hardware Description Language:** Verilog HDL  
**Project Date:** October 2026

---

## 1. Project Overview

The **32-Bit Floating-Point Logic Unit (FLU)** is a modular digital hardware design developed using Verilog Hardware Description Language (HDL). Its primary purpose is to perform fundamental floating-point arithmetic operations on 32-bit operands represented using the IEEE 754 single-precision binary floating-point format.

The design follows a modular architecture in which individual arithmetic units implement specific operations, while a top-level module selects the required operation and routes the result to the output.

The project also includes a Verilog testbench for functional simulation and verification of arithmetic results, operation selection, and division-by-zero behavior.

The implementation is intended for educational use, digital logic design practice, RTL development, and introductory FPGA-based arithmetic projects.

## 2. Project Objectives

The main objectives are to:

- Design a modular 32-bit floating-point arithmetic unit.
- Implement addition and subtraction, multiplication, division, squaring, and square root.
- Use IEEE 754 single-precision bit representation for operands and results.
- Develop reusable arithmetic modules in Verilog HDL.
- Integrate individual modules through a top-level FLU controller.
- Verify functional behavior using a dedicated testbench.
- Support RTL simulation and design exploration in Xilinx Vivado.
- Document the architecture, operation encoding, testing approach, and implementation limitations.

## 3. Supported Arithmetic Operations

The FLU uses a 3-bit operation selector to choose the required arithmetic function.

| Operation Code | Operation | Description |
|---|---|---|
| `3'b000` | Addition | Computes A + B |
| `3'b001` | Subtraction | Computes A − B |
| `3'b010` | Multiplication | Computes A × B |
| `3'b011` | Division | Computes A ÷ B |
| `3'b100` | Squaring | Computes A × A |
| `3'b101` | Square Root | Computes √A |

**Note:** These are the intended operation assignments for the documented design. The actual case statements in `flu_top.v` are the authoritative source if the implementation uses different encodings.

Squaring and square root operate on Operand A, while the binary arithmetic operations use both Operand A and Operand B.

## 4. IEEE 754 Single-Precision Format

Each operand and result is represented by a 32-bit IEEE 754-style single-precision floating-point word.

The format consists of three fields:

| Field | Bit Positions | Width |
|---|---|---:|
| Sign | `[31]` | 1 bit |
| Exponent | `[30:23]` | 8 bits |
| Fraction | `[22:0]` | 23 bits |

The bit layout is:

```text
 31           30                 23 22                       0
+---------------+------------------+--------------------------+
| Sign (1 bit)  | Exponent (8 bit) | Fraction / Mantissa (23) |
+---------------+------------------+--------------------------+
```

For normalized finite numbers, the represented value is:

\[
(-1)^S \times (1.F) \times 2^{E-127}
\]

Where:

- \(S\) is the sign bit.
- \(E\) is the unsigned stored exponent.
- \(F\) is the fractional part of the significand.
- 127 is the single-precision exponent bias.

The normalized representation includes an implicit leading `1` in the significand.

### Example: Hexadecimal to Floating-Point

Consider the 32-bit hexadecimal value:

```verilog
32'h3F9CC470
```

Its corresponding decimal value is:

```text
1.2247467041015625
```

This illustrates how the same 32-bit vector can represent a floating-point number rather than an ordinary integer.

**Important:** A 32-bit vector alone does not automatically perform floating-point arithmetic. The RTL logic must correctly interpret and manipulate its sign, exponent, and significand fields.

## 5. System Architecture

The FLU is organized into independent arithmetic modules connected through a top-level module.

```text
                    +----------------------+
                    |   Operand A (32-bit) |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |   Operand B (32-bit) |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |      FLU TOP         |
                    |  Operation Decoder   |
                    +----------+-----------+
                               |
             +-----------------+------------------+
             |                 |                  |
             v                 v                  v
       +-----------+     +-----------+      +-----------+
       | Add / Sub |     | Multiply  |      |  Divide   |
       +-----+-----+     +-----+-----+      +-----+-----+
             |                 |                  |
             +-----------------+------------------+
                               |
                   +-----------+-----------+
                   |                       |
                   v                       v
             +-----------+           +-----------+
             |  Square   |           | Square    |
             |           |           | Root      |
             +-----+-----+           +-----+-----+
                   |                       |
                   +-----------+-----------+
                               |
                               v
                    +----------------------+
                    |   Result (32-bit)    |
                    +----------------------+
```

*Conceptual architecture: the top-level module selects the output of the requested arithmetic unit. The exact internal connections depend on the RTL implementation.*

### Processing Flow

1. Provide 32-bit floating-point operands.
2. Set the 3-bit operation selector.
3. Decode the selected operation in the top-level module.
4. Execute the corresponding arithmetic logic.
5. Route the selected arithmetic result to the output.
6. Assert the division-by-zero status when supported and applicable.
7. Verify the result against the expected floating-point bit pattern in simulation.

## 6. Repository Structure

The project is organized into RTL source files, testbench files, documentation, and reports.

```text
FLU_Project/
|
+-- rtl/
|   +-- fp32_encode_comb.v
|   +-- fp32_add_sub.v
|   +-- fp32_mul.v
|   +-- fp32_div.v
|   +-- fp32_square.v
|   +-- fp32_sqrt.v
|   +-- flu_top.v
|
+-- tb/
|   +-- tb_flu_top.v
|
+-- docs/
|   +-- README.md
|   +-- design_notes.md
|
+-- reports/
|   +-- simulation_results.txt
|   +-- synthesis_summary.txt
|
+-- README.md
```

*The structure above describes the intended project organization. Filenames and report files should match the actual contents of your repository.*

### Module Descriptions

| File | Purpose |
|---|---|
| `fp32_encode_comb.v` | Converts supported decimal-style inputs into a 32-bit floating-point representation, if used by the design. |
| `fp32_add_sub.v` | Implements floating-point addition and subtraction. |
| `fp32_mul.v` | Implements floating-point multiplication. |
| `fp32_div.v` | Implements floating-point division. |
| `fp32_square.v` | Computes the square of Operand A. |
| `fp32_sqrt.v` | Computes the square root of Operand A. |
| `flu_top.v` | Integrates the arithmetic modules and selects the output based on the operation code. |
| `tb_flu_top.v` | Applies test vectors and checks simulation results. |
| `design_notes.md` | Provides supplementary implementation and design notes. |

## 7. Top-Level Interface

The principal module is `flu_top`.

Its documented interface includes the following signals:

| Signal | Direction | Width | Description |
|---|---|---:|---|
| `operand_a` | Input | 32 bits | First floating-point operand |
| `operand_b` | Input | 32 bits | Second floating-point operand |
| `operation` | Input | 3 bits | Arithmetic operation selector |
| `result` | Output | 32 bits | Floating-point result |
| `divide_by_zero` | Output | 1 bit | Indicates division by zero when implemented |

The design is combinational at the top level: it does not require a clock or reset for the basic arithmetic selection flow.

The exact interface should be verified against the port declarations in `flu_top.v`.

## 8. Simulation and Verification

The project includes a testbench named `tb_flu_top.v`, which applies input vectors, selects operations, waits for combinational logic to settle, and checks the resulting 32-bit output.

The testbench may include decimal input encoders where applicable and compares the resulting bit patterns with expected IEEE 754 representations.

### Example Test Vectors

The following examples illustrate common binary32 arithmetic results:

| Test | Operation | Inputs | Expected Result |
|---|---|---|---|
| 1 | Addition | 1.5 + 2.0 | 3.5 |
| 2 | Subtraction | 1.5 − 2.0 | −0.5 |
| 3 | Multiplication | 1.5 × 2.0 | 3.0 |
| 4 | Division | 1.5 ÷ 2.0 | 0.75 |
| 5 | Squaring | 1.5 × 1.5 | 2.25 |
| 6 | Square root | √4.0 | 2.0 |

For these exact values, the expected binary32 hexadecimal results are:

| Decimal Result | Expected Hexadecimal |
|---|---|
| 3.5 | `32'h40600000` |
| −0.5 | `32'hBF000000` |
| 3.0 | `32'h40400000` |
| 0.75 | `32'h3F400000` |
| 2.25 | `32'h40100000` |
| 2.0 | `32'h40000000` |

Additional tests should cover division by zero, negative operands, cancellation, and boundary conditions supported by the implementation.

These are reference vectors, not a claim that every listed test has already passed in the current RTL.

## 9. Running the Project in Xilinx Vivado

### Step 1: Open the Project

Launch Xilinx Vivado 2025.2.1 and create a new RTL project or open an existing project containing the FLU source files.

### Step 2: Add RTL Sources

Add the Verilog files from the `rtl/` directory:

- `flu_top.v`
- `fp32_add_sub.v`
- `fp32_mul.v`
- `fp32_div.v`
- `fp32_square.v`
- `fp32_sqrt.v`
- `fp32_encode_comb.v`, if required by the selected design flow.

### Step 3: Add Simulation Sources

Add `tb_flu_top.v` to the simulation sources.

Set the testbench module as the simulation top, while retaining `flu_top` as the RTL design top.

### Step 4: Run Behavioral Simulation

Select **Run Simulation → Run Behavioral Simulation**.

Inspect the waveform and simulator transcript for:

- Operation selector values.
- Input operand bit patterns.
- Output result values.
- Division-by-zero status.
- Testbench pass/fail messages.

### Step 5: Review the Results

Confirm that the output matches the expected hexadecimal floating-point value for each test case.

A passing testbench demonstrates correctness only for the scenarios it actually tests.

### Optional Command-Line Simulation

If Icarus Verilog is installed, a compatible source set can be compiled using:

```bash
iverilog -g2012 -s tb_flu_top -o flu_sim \
  rtl/*.v tb/tb_flu_top.v

vvp flu_sim
```

This assumes that all files in `rtl/` are compatible with Icarus Verilog and that the testbench uses compatible syntax. If the project contains additional modules or vendor-specific constructs, adjust the source list accordingly.

## 10. Design Limitations

This project is an educational baseline rather than a claim of full IEEE 754 compliance.

Depending on the individual arithmetic implementation, the following behaviors may be incomplete or unsupported:

- Full IEEE 754 rounding modes and correctly rounded results.
- Subnormal (denormalized) numbers.
- Complete handling of NaN and positive or negative infinity.
- Overflow and underflow detection and response.
- Signed zero and all exceptional arithmetic cases.
- Division-by-zero behavior beyond the implemented status signal.
- Negative inputs to square root and other invalid operations.
- Timing optimization and resource optimization for FPGA synthesis.

The design should be tested against the actual RTL before being used in safety-critical, production, or precision-sensitive applications.

## 11. Future Improvements

Potential enhancements include:

- Implementing IEEE 754 rounding-to-nearest, ties-to-even.
- Improving exception detection and propagation.
- Supporting subnormal values, infinities, and NaNs.
- Expanding the testbench with randomized and boundary-value testing.
- Adding assertions and self-checking reference-model comparisons.
- Evaluating synthesis resource utilization and maximum operating frequency.
- Optimizing arithmetic paths for FPGA implementation.
- Developing a pipelined architecture for higher throughput.
- Adding support for comparison and other arithmetic operations.

## 12. Applications

The project provides a starting point for exploring:

- Digital logic design and RTL verification.
- Floating-point number representation.
- FPGA arithmetic circuits.
- Arithmetic datapath design.
- Hardware simulation and testbench development.
- Computer architecture and hardware design coursework.

## 13. License

No license is specified in this document. Add an appropriate license file before distributing or reusing the project publicly.

## 14. Developer

**Ghulam Yaseen Nangraj**

Developer of the 32-Bit Floating-Point Logic Unit (FLU) in Verilog HDL.

The project demonstrates modular RTL design, floating-point arithmetic concepts, hardware simulation, and verification using Verilog HDL and Xilinx Vivado.

---

*32-Bit Floating-Point Logic Unit (FLU) in Verilog HDL — Educational RTL Design Project, October 2026.*