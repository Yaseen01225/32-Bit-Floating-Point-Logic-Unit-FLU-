`timescale 1ns / 1ps

// ============================================================================
// Project     : Floating-Point Logic Unit (FLU)
// File        : fp32_mul.v
// Developer   : Ghulam Yaseen Nangraj
// Date        : 2026-10-16
// Platform    : Xilinx Vivado v2025.2.1 / Verilog HDL
// Purpose     : Perform 32-bit floating-point multiplication.
// Description :
//   - Accepts two 32-bit floating-point operands.
//   - Calculates the result sign using the XOR of the operand signs.
//   - Adds the operand exponents and subtracts the IEEE-754 bias.
//   - Multiplies the significands and normalizes the product.
//   - Packs the sign, exponent, and fraction into a 32-bit result.
// Notes       : Educational baseline implementation.
//               Special values, subnormal numbers, and IEEE-754 rounding
//               are not fully supported.
// ============================================================================

module fp32_mul (
    input  wire [31:0] a,       // First 32-bit floating-point operand
    input  wire [31:0] b,       // Second 32-bit floating-point operand

    output reg  [31:0] result   // 32-bit floating-point product
);

    // ------------------------------------------------------------------------
    // Result sign
    // XOR produces a positive sign when operand signs match and a negative
    // sign when operand signs differ.
    // ------------------------------------------------------------------------
    reg sign_r;

    // ------------------------------------------------------------------------
    // Exponent fields
    // Each operand contains an 8-bit exponent with a bias of 127.
    // ------------------------------------------------------------------------
    reg [7:0] ea;               // Exponent of operand a
    reg [7:0] eb;               // Exponent of operand b

    // Nine bits are used to help detect exponent overflow and underflow.
    reg [8:0] er;               // Intermediate result exponent

    // ------------------------------------------------------------------------
    // Significands
    // The 23 stored fraction bits are extended to 24 bits by adding an
    // assumed implicit leading 1 for normalized operands.
    // This assumption is not valid for zero or subnormal operands.
    // ------------------------------------------------------------------------
    reg [23:0] ma;              // Significand of operand a
    reg [23:0] mb;              // Significand of operand b

    // ------------------------------------------------------------------------
    // Multiplication and result fraction
    // Multiplying two 24-bit significands produces a 48-bit product.
    // ------------------------------------------------------------------------
    reg [47:0] product;         // Full significand multiplication result
    reg [22:0] fraction;        // 23-bit fraction stored in the result

    // ------------------------------------------------------------------------
    // Combinational multiplication logic
    // The result is recalculated whenever an input changes.
    // ------------------------------------------------------------------------
    always @* begin

        // ====================================================================
        // STEP 1: Calculate the result sign
        // ====================================================================
        // IEEE-754 multiplication uses the XOR of the operand sign bits.
        sign_r = a[31] ^ b[31];

        // ====================================================================
        // STEP 2: Extract operand exponents
        // ====================================================================
        ea = a[30:23];          // Extract exponent of operand a
        eb = b[30:23];          // Extract exponent of operand b

        // ====================================================================
        // STEP 3: Extract and extend operand significands
        // ====================================================================
        // Add an assumed leading 1 to each 23-bit fraction.
        ma = {1'b1, a[22:0]};
        mb = {1'b1, b[22:0]};

        // ====================================================================
        // STEP 4: Multiply the significands
        // ====================================================================
        // A 24-bit value multiplied by another 24-bit value produces
        // a 48-bit product.
        product = ma * mb;

        // ====================================================================
        // STEP 5: Calculate the result exponent
        // ====================================================================
        // The stored exponents both use a bias of 127.
        // Therefore, add the exponents and subtract one bias:
        //
        //     result exponent = ea + eb - 127
        //
        // The extra bit helps represent intermediate overflow conditions.
        er = {1'b0, ea} + {1'b0, eb} - 9'd127;

        // Initialize outputs and intermediate fraction.
        fraction = 23'd0;
        result   = 32'd0;

        // ====================================================================
        // STEP 6: Normalize the product
        // ====================================================================
        // The product of two normalized significands lies in the range
        // [1, 4). If product[47] is set, the product is at least 2 and
        // must be shifted right by one bit. The exponent is increased.
        if (product[47]) begin

            // Select the fraction bits for the normalized product.
            fraction = product[46:24];

            // Increase the exponent to compensate for normalization.
            er = er + 1'b1;

        end else begin

            // The product is already in the [1, 2) range.
            // Select the corresponding fraction bits.
            fraction = product[45:23];

        end

        // ====================================================================
        // STEP 7: Check the exponent range and pack the result
        // ====================================================================

        // Exponent 255 is reserved for infinity and NaN in IEEE-754.
        // This implementation generates infinity for exponent overflow.
        if (er >= 255) begin

            result = {sign_r, 8'hFF, 23'd0};

        // Treat exponent zero or a negative intermediate exponent as zero.
        // Subnormal result generation is not implemented.
        end else if (er == 0 || er[8]) begin

            result = 32'd0;

        end else begin

            // Assemble the final single-precision result:
            // [31]    = sign
            // [30:23] = exponent
            // [22:0]  = fraction
            result = {sign_r, er[7:0], fraction};

        end

    end

endmodule