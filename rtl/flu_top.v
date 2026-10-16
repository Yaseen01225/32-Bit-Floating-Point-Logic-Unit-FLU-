// ============================================================================
// Project   : Floating-Point Logic Unit (FLU)
// File      : flu_top.v
// Developer : Ghulam Yaseen Nangraj
// Date      : 2026-10-16
// Platform  : Xilinx Vivado v2025.2.1
//
// Purpose:
//   This module acts as the top-level controller of the Floating-Point Logic
//   Unit (FLU). It receives two 32-bit IEEE 754 single-precision floating-point
//   operands, selects the requested arithmetic operation, and forwards the
//   corresponding result to the output.
//
// Supported Operations:
//   000 = Addition
//   001 = Subtraction
//   010 = Multiplication
//   011 = Division
//   100 = Square
//   101 = Square Root
//
// Notes:
//   - The design uses combinational logic and requires no clock or reset.
//   - Individual arithmetic modules calculate their results independently.
//   - The operation selector chooses which result reaches the output.
//   - The divide_by_zero output reports the divider's zero-divisor status.
//   - Refer to README.md for design assumptions and IEEE 754 limitations.
// ============================================================================


// Defines the simulation time unit as 1 nanosecond.
// Defines the simulation time precision as 1 picosecond.
`timescale 1ns / 1ps


// ============================================================================
// MODULE DECLARATION AND PORT DEFINITIONS
// ============================================================================

// Declares the top-level module named flu_top.
// This module connects the individual floating-point arithmetic units.
module flu_top(

    // Input operand A.
    // Contains a 32-bit IEEE 754 single-precision floating-point value.
    input wire [31:0] operand_a,

    // Input operand B.
    // Contains the second 32-bit IEEE 754 floating-point value.
    // It is used by addition, subtraction, multiplication, and division.
    // Square and square root use operand_a in this implementation.
    input wire [31:0] operand_b,

    // Three-bit operation selector.
    // Determines which arithmetic result is selected for the output.
    // 000 = Addition
    // 001 = Subtraction
    // 010 = Multiplication
    // 011 = Division
    // 100 = Square
    // 101 = Square Root
    input wire [2:0] operation,

    // Output carrying the selected 32-bit floating-point result.
    // Declared as reg because it is assigned inside an always block.
    output reg [31:0] result,

    // Status output indicating division by zero.
    // Set to 1 when division is selected and the divider reports a zero
    // divisor. Set to 0 for other operations in this implementation.
    output reg divide_by_zero
);


// ============================================================================
// INTERNAL SIGNAL DECLARATIONS
// ============================================================================

// These wires carry the outputs of the individual arithmetic modules.
// Each arithmetic unit calculates its result independently.
//
// add_r    : Addition result.
// sub_r    : Subtraction result.
// mul_r    : Multiplication result.
// div_r    : Division result.
// square_r : Square result.
// root_r   : Square-root result.
//
// Each result is a 32-bit IEEE 754 single-precision bit pattern.
wire [31:0] add_r;
wire [31:0] sub_r;
wire [31:0] mul_r;
wire [31:0] div_r;
wire [31:0] square_r;
wire [31:0] root_r;


// Internal status wire connected to the divider.
// It indicates whether the division operation encountered a zero divisor.
// This signal is forwarded to the top-level divide_by_zero output when
// the division operation is selected.
wire div0;


// ============================================================================
// FLOATING-POINT ADDITION UNIT
// ============================================================================

// Instantiates the fp32_add_sub module to perform floating-point addition.
//
// Port order:
//   1. operand_a : First floating-point operand.
//   2. operand_b : Second floating-point operand.
//   3. 1'b0      : Selects addition instead of subtraction.
//   4. add_r     : Receives the addition result.
//
// The subtract control is set to logic 0, so the module performs:
//
//   add_r = operand_a + operand_b
//
// The actual arithmetic behavior depends on the implementation of fp32_add_sub.
fp32_add_sub add_unit(
    operand_a,
    operand_b,
    1'b0,
    add_r
);


// ============================================================================
// FLOATING-POINT SUBTRACTION UNIT
// ============================================================================

// Instantiates another fp32_add_sub module for subtraction.
//
// The first two ports receive the floating-point operands.
// The third port is set to logic 1 to select subtraction.
// The final port carries the calculated result.
//
// The module is expected to perform:
//
//   sub_r = operand_a - operand_b
//
// This implementation reuses the same module for both addition and
// subtraction, reducing the need for a separate subtractor module.
fp32_add_sub sub_unit(
    operand_a,
    operand_b,
    1'b1,
    sub_r
);


// ============================================================================
// FLOATING-POINT MULTIPLICATION UNIT
// ============================================================================

// Instantiates the fp32_mul module.
//
// Port order:
//   1. operand_a : First multiplicand.
//   2. operand_b : Second multiplicand.
//   3. mul_r     : Receives the multiplication result.
//
// The module is expected to calculate:
//
//   mul_r = operand_a * operand_b
//
// The result is calculated continuously and is available for selection
// by the top-level operation-selection logic.
fp32_mul mul_unit(
    operand_a,
    operand_b,
    mul_r
);


// ============================================================================
// FLOATING-POINT DIVISION UNIT
// ============================================================================

// Instantiates the fp32_div module.
//
// Port order:
//   1. operand_a : Dividend.
//   2. operand_b : Divisor.
//   3. div_r     : Receives the division result.
//   4. div0      : Receives the division-by-zero status.
//
// The module is expected to calculate:
//
//   div_r = operand_a / operand_b
//
// The div0 output reports a zero-divisor condition according to the
// divider's implementation.
//
// Keeping the status on an internal wire allows the top-level module to
// expose it only when division is the selected operation.
fp32_div div_unit(
    operand_a,
    operand_b,
    div_r,
    div0
);


// ============================================================================
// FLOATING-POINT SQUARE UNIT
// ============================================================================

// Instantiates the fp32_square module.
//
// Port order:
//   1. operand_a : Input value to be squared.
//   2. square_r  : Receives the square result.
//
// The module is expected to calculate:
//
//   square_r = operand_a * operand_a
//
// Operand B is not used by this square unit.
//
// The calculated result is continuously available on square_r.
fp32_square square_unit(
    operand_a,
    square_r
);


// ============================================================================
// FLOATING-POINT SQUARE-ROOT UNIT
// ============================================================================

// Instantiates the fp32_sqrt module.
//
// Port order:
//   1. operand_a : Input value whose square root is calculated.
//   2. root_r    : Receives the square-root result.
//
// The module is expected to calculate:
//
//   root_r = sqrt(operand_a)
//
// Operand B is not used by this square-root unit.
//
// The square-root implementation must define its behavior for negative
// inputs and special IEEE 754 values.
fp32_sqrt square_root(
    operand_a,
    root_r
);


// ============================================================================
// COMBINATIONAL RESULT-SELECTION LOGIC
// ============================================================================

// This always block implements a combinational multiplexer.
//
// Whenever operation or any other signal read by this block changes,
// the block reevaluates and updates the outputs.
//
// Because every output is assigned a value on every execution path,
// this block does not infer a latch.
always @* begin

    // Set the default result to positive zero.
    // This value is used if no supported operation code matches.
    // It also prevents result from retaining a previous value.
    result = 32'h00000000;


    // Clear the division-by-zero status by default.
    // The flag is meaningful only when division is selected.
    // Clearing it here prevents a previous division status from remaining
    // asserted during addition, subtraction, multiplication, square,
    // square root, or an unsupported operation code.
    divide_by_zero = 1'b0;


    // Examine the operation selector to determine which arithmetic
    // result should be forwarded to the top-level result output.
    case (operation)

        // --------------------------------------------------------------------
        // Operation 000: ADDITION
        // --------------------------------------------------------------------

        // Select the result generated by the floating-point adder.
        3'b000: result = add_r;


        // --------------------------------------------------------------------
        // Operation 001: SUBTRACTION
        // --------------------------------------------------------------------

        // Select the result generated by the floating-point subtractor.
        3'b001: result = sub_r;


        // --------------------------------------------------------------------
        // Operation 010: MULTIPLICATION
        // --------------------------------------------------------------------

        // Select the result generated by the floating-point multiplier.
        3'b010: result = mul_r;


        // --------------------------------------------------------------------
        // Operation 011: DIVISION
        // --------------------------------------------------------------------

        // A begin-end block groups the assignments associated with division.
        // Both the division result and its status flag must be forwarded.
        3'b011: begin

            // Send the divider's calculated result to the output.
            result = div_r;

            // Forward the divider's zero-divisor status.
            // This is normally 1 when operand_b is zero and division is active.
            divide_by_zero = div0;

        end


        // --------------------------------------------------------------------
        // Operation 100: SQUARE
        // --------------------------------------------------------------------

        // Select the square of operand_a.
        3'b100: result = square_r;


        // --------------------------------------------------------------------
        // Operation 101: SQUARE ROOT
        // --------------------------------------------------------------------

        // Select the square root of operand_a.
        3'b101: result = root_r;


        // No default branch is required to prevent a latch because result
        // and divide_by_zero have already been assigned default values.
        // For an unsupported operation code, those default values remain.

    endcase

// End of the combinational always block.
end


// ============================================================================
// END OF MODULE
// ============================================================================

// Marks the end of the top-level flu_top module.
endmodule