/*
 * ============================================================================
 * Project   : Floating-Point Logic Unit (FLU)
 * Module    : fp32_div
 * Developer : Replace with your name
 * Date      : 2026-10-16
 * Platform  : Xilinx Vivado / Verilog HDL
 *
 * Purpose:
 *   Educational implementation of a 32-bit IEEE 754-style
 *   single-precision floating-point division unit.
 *
 * Functionality:
 *   - Calculates the sign of the quotient.
 *   - Computes the exponent difference.
 *   - Divides the significands.
 *   - Normalizes the quotient.
 *   - Detects division by zero.
 *   - Handles exponent overflow and underflow.
 *
 * Limitations:
 *   - Assumes normalized input significands.
 *   - Does not fully handle NaN, infinity, or subnormal operands.
 *   - Does not implement IEEE 754 rounding.
 *   - Underflow results are flushed to zero.
 *   - Division by zero produces a signed infinity.
 * ============================================================================
 */

`timescale 1ns / 1ps

module fp32_div (
    input  wire [31:0] a,               // Dividend
    input  wire [31:0] b,               // Divisor

    output reg  [31:0] result,          // Floating-point quotient
    output reg         divide_by_zero   // Asserted when divisor is zero
);

    // ------------------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------------------

    reg        sign_r;                  // Sign bit of the quotient

    reg [7:0]  ea;                      // Exponent of operand A
    reg [7:0]  eb;                      // Exponent of operand B

    reg signed [10:0] er;               // Intermediate result exponent

    reg [23:0] ma;                      // Significand of operand A
    reg [23:0] mb;                      // Significand of operand B

    reg [47:0] numerator;               // Scaled dividend significand
    reg [47:0] quotient;                // Division result

    reg [22:0] fraction;                // Output fraction field

    // ------------------------------------------------------------------------
    // Combinational division logic
    // ------------------------------------------------------------------------

    always @* begin

        // --------------------------------------------------------------------
        // Step 1: Extract operand fields
        // --------------------------------------------------------------------

        sign_r = a[31] ^ b[31];

        ea = a[30:23];
        eb = b[30:23];

        // Calculate the output exponent:
        // E_result = E_A - E_B + Bias
        // Bias = 127 for IEEE 754 single precision.
        er = $signed({3'b000, ea})
           - $signed({3'b000, eb})
           + 11'sd127;

        // Restore the implicit leading 1.
        // This assumes both operands are normalized numbers.
        ma = {1'b1, a[22:0]};
        mb = {1'b1, b[22:0]};

        // --------------------------------------------------------------------
        // Step 2: Initialize intermediate and output values
        // --------------------------------------------------------------------

        numerator       = {ma, 24'd0};
        quotient        = 48'd0;
        fraction        = 23'd0;
        result          = 32'd0;

        // Detect positive or negative zero in the divisor.
        divide_by_zero = (b[30:0] == 31'd0);

        // --------------------------------------------------------------------
        // Step 3: Handle division by zero
        // --------------------------------------------------------------------

        if (divide_by_zero) begin

            // Return signed infinity when dividing by zero.
            result = {sign_r, 8'hFF, 23'd0};

        end else begin

            // ---------------------------------------------------------------
            // Step 4: Divide the scaled significands
            // ---------------------------------------------------------------

            quotient = numerator / mb;

            // ---------------------------------------------------------------
            // Step 5: Normalize the quotient
            // ---------------------------------------------------------------

            // If quotient[24] is set, the quotient is already normalized.
            if (quotient[24]) begin

                fraction = quotient[23:1];

            end else begin

                // Shift the fraction representation and decrease exponent.
                fraction = quotient[22:0];
                er       = er - 1;

            end

            // ---------------------------------------------------------------
            // Step 6: Check exponent range
            // ---------------------------------------------------------------

            // Exponent overflow: return signed infinity.
            if (er >= 255) begin

                result = {sign_r, 8'hFF, 23'd0};

            end

            // Exponent underflow: flush the result to positive zero.
            else if (er <= 0) begin

                result = 32'd0;

            end

            // ---------------------------------------------------------------
            // Step 7: Assemble the floating-point result
            // ---------------------------------------------------------------

            else begin

                result = {sign_r, er[7:0], fraction};

            end

        end

    end

endmodule