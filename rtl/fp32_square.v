/*
 * ============================================================================
 * Project   : Floating-Point Logic Unit (FLU)
 * Module    : fp32_square
 * Developer : Ghulam Yaseen Nangraj
 * Date      : 2026-10-16
 * Platform  : Xilinx Vivado v2025.2.1 / Verilog HDL
 *
 * Purpose:
 *   Calculates the square of a 32-bit IEEE 754-style single-precision
 *   floating-point input.
 *
 * Operation:
 *   result = a * a
 *
 * Features:
 *   - 32-bit floating-point input and output.
 *   - 24-bit significand multiplication.
 *   - Exponent calculation and product normalization.
 *   - Detection of zero, infinity, and NaN.
 *   - Exponent overflow and underflow handling.
 *
 * Limitations:
 *   - Uses truncation instead of IEEE 754 rounding.
 *   - Does not support gradual underflow.
 *   - Subnormal inputs are flushed to zero.
 *   - Intended for educational use.
 * ============================================================================
 */

`timescale 1ns / 1ps

module fp32_square (
    input  wire [31:0] a,        // 32-bit floating-point input
    output reg  [31:0] result    // Square of the input
);

    // ------------------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------------------

    reg [7:0]  ea;               // Input exponent

    reg [22:0] fa;               // Input fraction

    reg [23:0] ma;               // Input significand including hidden bit

    reg [47:0] product;          // 24-bit x 24-bit significand product

    reg signed [10:0] er;        // Intermediate output exponent

    reg [22:0] fraction;         // Output fraction

    // ------------------------------------------------------------------------
    // Combinational floating-point squaring logic
    // ------------------------------------------------------------------------

    always @* begin

        // --------------------------------------------------------------------
        // Step 1: Extract input fields
        // --------------------------------------------------------------------

        ea = a[30:23];
        fa = a[22:0];

        // --------------------------------------------------------------------
        // Step 2: Initialize intermediate values
        // --------------------------------------------------------------------

        ma       = 24'd0;
        product  = 48'd0;
        er       = 11'sd0;
        fraction = 23'd0;
        result   = 32'd0;

        // --------------------------------------------------------------------
        // Step 3: Handle special input values
        // --------------------------------------------------------------------

        // Exponent 255 represents infinity or NaN.
        if (ea == 8'hFF) begin

            // A nonzero fraction represents NaN.
            if (fa != 23'd0) begin

                // Return a quiet NaN.
                result = {1'b0, 8'hFF, 1'b1, 22'd0};

            end else begin

                // Squaring positive or negative infinity gives +infinity.
                result = {1'b0, 8'hFF, 23'd0};

            end

        end

        // Exponent zero represents zero or a subnormal input.
        else if (ea == 8'd0) begin

            // Zero squared is zero.
            // Subnormal input squared also rounds to zero in binary32.
            result = 32'd0;

        end

        // --------------------------------------------------------------------
        // Step 4: Process normalized finite input
        // --------------------------------------------------------------------

        else begin

            // Restore the implicit leading 1:
            // M = 1.fraction
            ma = {1'b1, fa};

            // Square the significand.
            // The product contains up to 48 significant bits.
            product = ma * ma;

            // Calculate the exponent with bias correction.
            //
            // E_result = E_a + E_a - Bias
            // Bias     = 127
            //
            // The exponent may require an additional increment
            // during normalization.
            er = ($signed({3'b000, ea}) * 11'sd2)
               - 11'sd127;

            // ---------------------------------------------------------------
            // Step 5: Normalize the significand product
            // ---------------------------------------------------------------

            // If product[47] is set, the product is at least 2.0.
            // Shift the normalized significand right by one bit
            // and increase the exponent.
            if (product[47]) begin

                fraction = product[46:24];
                er       = er + 11'sd1;

            end else begin

                // Otherwise, the product is in the range [1.0, 2.0).
                fraction = product[45:23];

            end

            // ---------------------------------------------------------------
            // Step 6: Check exponent overflow and underflow
            // ---------------------------------------------------------------

            // Overflow: return positive infinity.
            if (er >= 255) begin

                result = {1'b0, 8'hFF, 23'd0};

            end

            // Underflow: flush the result to positive zero.
            else if (er <= 0) begin

                result = 32'd0;

            end

            // ---------------------------------------------------------------
            // Step 7: Assemble the final floating-point result
            // ---------------------------------------------------------------

            else begin

                // The sign bit is always zero because a squared
                // real number cannot be negative.
                result = {1'b0, er[7:0], fraction};

            end

        end

    end

endmodule
