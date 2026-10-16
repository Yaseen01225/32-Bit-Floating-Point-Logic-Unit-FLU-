`timescale 1ns / 1ps
// ============================================================================
// Project     : Floating-Point Logic Unit (FLU)
// File        : fp32_add_sub.v
// Developer   : Ghulam Yaseen Nangraj
// Date        : 2026-10-16
// Platform    : Xilinx Vivado v2025.2.1 / Verilog HDL
// Purpose     : Perform 32-bit floating-point addition and subtraction.
// Description :
//   - Accepts two 32-bit floating-point operands (a and b).
//   - Uses the subtract control signal to select addition or subtraction.
//   - Aligns operand significands according to their exponents.
//   - Adds or subtracts the significands based on their effective signs.
//   - Performs basic normalization and generates the 32-bit result.
// Notes       : Educational baseline implementation.
//               Does not fully handle IEEE-754 special values, subnormals,
//               guard/round/sticky bits, or rounding modes.
// ============================================================================

module fp32_add_sub (
    input  wire [31:0] a,          // First 32-bit floating-point operand
    input  wire [31:0] b,          // Second 32-bit floating-point operand
    input  wire        subtract,   // 0 = addition, 1 = subtraction

    output reg  [31:0] result      // 32-bit floating-point result
);

    // ------------------------------------------------------------------------
    // Sign bits
    // ------------------------------------------------------------------------
    reg sa;                        // Sign bit of operand a
    reg sb;                        // Effective sign bit of operand b
    reg sr;                        // Sign bit of the result

    // ------------------------------------------------------------------------
    // Exponent fields
    // ------------------------------------------------------------------------
    reg [7:0] ea;                  // Exponent of operand a
    reg [7:0] eb;                  // Effective exponent of operand b
    reg [7:0] er;                  // Exponent of the result
    reg [7:0] ediff;               // Difference between operand exponents

    // ------------------------------------------------------------------------
    // Significands (mantissas)
    // ------------------------------------------------------------------------
    reg [23:0] ma;                 // Significand of operand a, including
                                   // an assumed implicit leading 1
    reg [23:0] mb;                 // Significand of operand b, including
                                   // an assumed implicit leading 1

    // Extended significand registers used during arithmetic
    reg [24:0] large_m;            // Significand with larger exponent
    reg [24:0] small_m;            // Significand with smaller exponent
    reg [24:0] aligned_m;          // Smaller significand after alignment
    reg [24:0] magnitude;          // Calculated result magnitude

    // ------------------------------------------------------------------------
    // Operand selection and intermediate arithmetic
    // ------------------------------------------------------------------------
    reg [7:0]  large_e;            // Larger of the two operand exponents
    reg        large_s;            // Sign of the selected larger-exponent operand
    reg        small_s;            // Sign of the selected smaller-exponent operand
    reg [24:0] sum_m;              // Intermediate significand sum
    integer    k;                  // Loop counter for normalization

    // ------------------------------------------------------------------------
    // Combinational floating-point addition/subtraction logic
    // Recalculates the result whenever an input or internal dependency changes.
    // ------------------------------------------------------------------------
    always @* begin

        // ====================================================================
        // STEP 1: Extract operand fields
        // ====================================================================

        // Extract the sign bits from the most significant bit.
        sa = a[31];

        // For subtraction, invert b's sign to convert a - b into a + (-b).
        sb = b[31] ^ subtract;

        // Extract the 8-bit exponent fields.
        ea = a[30:23];
        eb = b[30:23];

        // Extract the 23 stored fraction bits and prepend an assumed leading 1.
        // This assumption is valid for normalized values, but not for zero
        // or subnormal IEEE-754 numbers.
        ma = {1'b1, a[22:0]};
        mb = {1'b1, b[22:0]};

        // ====================================================================
        // STEP 2: Initialize intermediate values
        // Prevent unintended latch inference by assigning default values
        // before executing the conditional arithmetic.
        // ====================================================================
        result    = 32'd0;
        sr        = 1'b0;
        er        = 8'd0;
        ediff     = 8'd0;
        large_m   = 25'd0;
        small_m   = 25'd0;
        aligned_m = 25'd0;
        magnitude = 25'd0;
        large_e   = 8'd0;
        large_s   = 1'b0;
        small_s   = 1'b0;
        sum_m     = 25'd0;

        // ====================================================================
        // STEP 3: Compare exponents and select operand order
        // The operand with the larger exponent becomes the reference operand.
        // ====================================================================
        if (ea >= eb) begin

            // Operand a has the larger or equal exponent.
            large_e = ea;
            large_m = {1'b0, ma};
            small_m = {1'b0, mb};

            // Calculate the exponent difference for significand alignment.
            ediff = ea - eb;

            // Keep each operand's effective sign with its significand.
            large_s = sa;
            small_s = sb;

        end else begin

            // Operand b has the larger exponent.
            large_e = eb;
            large_m = {1'b0, mb};
            small_m = {1'b0, ma};

            // Calculate the exponent difference for significand alignment.
            ediff = eb - ea;

            // Keep each operand's effective sign with its significand.
            large_s = sb;
            small_s = sa;

        end

        // ====================================================================
        // STEP 4: Align the smaller significand
        // Right-shift the smaller significand by the exponent difference.
        // If the difference is too large, discard the smaller significand.
        // ====================================================================
        if (ediff >= 25)
            aligned_m = 25'd0;
        else
            aligned_m = small_m >> ediff;

        // Begin with the exponent of the larger-exponent operand.
        er = large_e;

        // ====================================================================
        // STEP 5: Perform addition or subtraction
        // Same effective signs: add magnitudes.
        // Different effective signs: subtract the smaller magnitude from
        // the larger magnitude.
        // ====================================================================
        if (large_s == small_s) begin

            // ---------------------------------------------------------------
            // Same signs: add the aligned significands.
            // ---------------------------------------------------------------
            sum_m = large_m + aligned_m;

            // The result keeps the common operand sign.
            sr = large_s;

            // If bit 24 is set, the sum overflowed the current significand
            // width and must be shifted right once.
            if (sum_m[24]) begin
                magnitude = sum_m >> 1;
                er        = large_e + 1'b1;
            end else begin
                magnitude = sum_m;
            end

        end else begin

            // ---------------------------------------------------------------
            // Different signs: subtract the smaller magnitude from the larger.
            // ---------------------------------------------------------------
            if (large_m >= aligned_m) begin

                // The larger-exponent operand's magnitude is at least as large
                // as the aligned smaller operand's magnitude.
                magnitude = large_m - aligned_m;
                sr        = large_s;

            end else begin

                // The aligned smaller operand has the greater magnitude.
                magnitude = aligned_m - large_m;
                sr        = small_s;

            end

            // ---------------------------------------------------------------
            // Basic left normalization
            // Shift the magnitude left until bit 23 is set, adjusting the
            // exponent downward for each shift.
            // Stop if the magnitude is zero or the exponent reaches 1.
            // ---------------------------------------------------------------
            for (k = 0; k < 24; k = k + 1) begin
                if (!magnitude[23] && magnitude != 0 && er > 1) begin
                    magnitude = magnitude << 1;
                    er        = er - 1'b1;
                end
            end

        end

        // ====================================================================
        // STEP 6: Construct the final 32-bit result
        // Format: {sign bit, 8-bit exponent, 23-bit fraction}.
        // ====================================================================

        // Exact cancellation produces positive zero in this implementation.
        if (magnitude == 0) begin
            result = 32'd0;

        // An exponent of 255 is encoded as infinity here.
        // NaN propagation and overflow details are not fully implemented.
        end else if (er >= 255) begin
            result = {sr, 8'hFF, 23'd0};

        // This implementation treats exponent zero as zero rather than
        // generating a subnormal result.
        end else if (er == 0) begin
            result = 32'd0;

        end else begin

            // Pack the sign, exponent, and fraction into the output.
            // The leading significand bit is omitted from the stored fraction.
            result = {sr, er, magnitude[22:0]};
        end
    end
endmodule
