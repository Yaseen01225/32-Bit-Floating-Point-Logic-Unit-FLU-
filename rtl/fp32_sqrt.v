/* ============================================================================
 * Project   : Floating-Point Logic Unit (FLU)
 * File      : fp32_sqrt.v
 * Module    : fp32_sqrt
 * Developer : Ghulam Yaseen Nangraj
 * Date      : 2026-10-16
 * Platform  : Xilinx Vivado v2025.2.1 / Verilog HDL
 *
 * Purpose:
 *   Calculates the square root of a 32-bit IEEE-754-style binary32 input.
 *   The module uses integer arithmetic and a digit-by-digit square-root
 *   algorithm to calculate the output significand.
 *
 * Interface:
 *   a      : 32-bit floating-point input.
 *   result : 32-bit floating-point square-root result.
 *
 * IEEE-754 Binary32 Format:
 *   Bit 31     : Sign bit.
 *   Bits 30:23 : 8-bit biased exponent.
 *   Bits 22:0  : 23-bit fraction field.
 *
 * Implementation:
 *   - Combinational integer square-root datapath.
 *   - Restores the implicit leading significand bit for normal inputs.
 *   - Adjusts odd exponents before calculating the square root.
 *   - Handles signed zero, infinity, and NaN cases.
 *   - Negative finite inputs produce a quiet NaN.
 *
 * Limitations:
 *   - The significand is truncated; round-to-nearest is not implemented.
 *   - Positive subnormal inputs are flushed to zero.
 *   - Overflow and underflow handling is simplified.
 *   - This module is not fully IEEE-754 compliant.
 *   - No clock or reset is required because the module is combinational.
 * ============================================================================ */

// Defines the simulation time unit as 1 nanosecond.
// Defines the simulation time precision as 1 picosecond.
`timescale 1ns / 1ps


// ============================================================================
// MODULE DECLARATION AND PORTS
// ============================================================================

module fp32_sqrt (

    // Input floating-point value in IEEE-754 binary32 format.
    input wire [31:0] a,

    // Output floating-point square root in IEEE-754 binary32 format.
    // Declared as reg because it is assigned inside an always block.
    output reg [31:0] result
);


// ============================================================================
// SECTION 1: INPUT FIELD REGISTERS
// ============================================================================

// Stores the sign bit extracted from the input.
// 0 = positive; 1 = negative.
reg sign_a;


// Stores the 8-bit biased exponent extracted from the input.
// Exponent 0 represents zero or subnormal values.
// Exponent 255 represents infinity or NaN.
// Exponents 1 through 254 represent normal finite values.
reg [7:0] exponent_a;


// Stores the 23-bit fraction field extracted from the input.
// For normal numbers, the significand includes an implicit leading 1.
reg [22:0] fraction_a;


// ============================================================================
// SECTION 2: EXPONENT CALCULATION REGISTERS
// ============================================================================

// Stores the unbiased exponent of the input.
//
//   unbiased_exp = exponent_a - 127
//
// The IEEE-754 exponent bias for binary32 is 127.
// The signed register permits negative exponent values.
reg signed [10:0] unbiased_exp;


// Stores the exponent after adjustment to an even number.
// An even exponent simplifies the square-root calculation:
//
//   sqrt(M * 2^E) = sqrt(M) * 2^(E/2)
//
// When E is odd, the significand is scaled by 2 and the exponent is
// decreased by 1 before division by 2.
reg signed [10:0] adjusted_exp;


// Stores the output exponent before it is packed into the final result.
//
//   output_exp = adjusted_exp / 2 + 127
//
// This register is signed so that negative intermediate exponents can
// be detected during simplified underflow handling.
reg signed [10:0] output_exp;


// ============================================================================
// SECTION 3: SIGNIFICAND AND INTEGER SQUARE-ROOT REGISTERS
// ============================================================================

// Stores the 24-bit significand of a normalized input.
//
// The original fraction contains 23 bits. Normalized IEEE-754 values have
// an implicit leading 1, which is restored here:
//
//   significand = {1'b1, fraction_a}
//
// The resulting value ranges from 1.0 to just under 2.0 when interpreted
// as a binary significand with 23 fractional bits.
reg [23:0] significand;


// Stores the scaled integer value whose square root is calculated.
//
// The significand is shifted according to the parity of the input exponent.
// The scaling places sufficient precision in the integer radicand for the
// 24-bit digit-by-digit square-root algorithm.
reg [47:0] radicand;


// Stores the partial remainder during the integer square-root calculation.
// Each iteration brings down the next two radicand bits and updates
// the remainder according to the trial subtraction.
reg [25:0] remainder;


// Stores the trial subtraction value used to decide the next root bit.
// The trial value is derived from the partial root.
reg [25:0] trial;


// Stores the integer square-root result as it is calculated one bit at a time.
// The final 24-bit value contains the calculated significand, subject to
// the truncation behavior of this implementation.
reg [23:0] root;


// Stores the next two-bit group extracted from the radicand.
// The square-root algorithm processes two input bits per iteration.
reg [1:0] next_pair;


// Integer loop counter used to process the 24 two-bit groups.
// The loop runs from bit-pair index 23 down to index 0.
integer i;


// ============================================================================
// SECTION 4: COMBINATIONAL SQUARE-ROOT LOGIC
// ============================================================================

// The always @* block reevaluates whenever a signal read inside the block
// changes. It performs input decoding, special-case handling, exponent
// adjustment, integer square-root calculation, and output packing.
//
// All registers assigned in this block receive default values to avoid
// unintended latch inference.
always @* begin


    // ========================================================================
    // STEP 1: EXTRACT THE INPUT IEEE-754 FIELDS
    // ========================================================================

    // Extract bit 31 as the input sign.
    sign_a = a[31];


    // Extract bits 30:23 as the biased exponent.
    exponent_a = a[30:23];


    // Extract bits 22:0 as the fraction field.
    fraction_a = a[22:0];


    // Initialize the unbiased exponent to zero.
    unbiased_exp = 11'sd0;


    // Initialize the adjusted exponent to zero.
    adjusted_exp = 11'sd0;


    // Initialize the output exponent to zero.
    output_exp = 11'sd0;


    // Initialize the significand.
    significand = 24'd0;


    // Initialize the radicand.
    radicand = 48'd0;


    // Initialize the partial remainder.
    remainder = 26'd0;


    // Initialize the trial subtraction value.
    trial = 26'd0;


    // Initialize the integer square-root accumulator.
    root = 24'd0;


    // Initialize the next two-bit group.
    next_pair = 2'b00;


    // Set the default output to positive zero.
    // Each special-case or normal-input branch overwrites this value
    // when necessary.
    result = 32'h00000000;


    // ========================================================================
    // STEP 2: HANDLE INFINITY AND NaN
    // ========================================================================

    // An exponent field of all ones indicates either infinity or NaN.
    //
    // If the fraction is zero, the input is infinity.
    // If the fraction is nonzero, the input is NaN.
    if (exponent_a == 8'hFF) begin

        // A nonzero fraction identifies a NaN input.
        if (fraction_a != 23'd0) begin

            // Return a quiet NaN with a positive sign.
            // The most significant fraction bit is set to indicate a quiet NaN.
            result = {1'b0, 8'hFF, 1'b1, 22'd0};

        end

        // A zero fraction and a set sign indicate negative infinity.
        else if (sign_a) begin

            // The square root of negative infinity is not a real number.
            // Return a quiet NaN.
            result = {1'b0, 8'hFF, 1'b1, 22'd0};

        end

        // A zero fraction and a clear sign indicate positive infinity.
        else begin

            // The square root of positive infinity is positive infinity.
            // Sign = 0, exponent = 255, fraction = 0.
            result = {1'b0, 8'hFF, 23'd0};

        end

    end


    // ========================================================================
    // STEP 3: HANDLE ZERO AND SUBNORMAL INPUTS
    // ========================================================================

    // An exponent field of zero represents either signed zero or a subnormal
    // floating-point value.
    else if (exponent_a == 8'd0) begin

        // A zero fraction means the input is exactly positive or negative zero.
        if (fraction_a == 23'd0) begin

            // Preserve the input sign.
            // This implementation uses sqrt(-0) = -0.
            result = {sign_a, 31'd0};

        end

        // A nonzero fraction with a negative sign represents a negative
        // subnormal number.
        else if (sign_a) begin

            // The square root of a negative nonzero real number is not real.
            // Return a quiet NaN.
            result = {1'b0, 8'hFF, 1'b1, 22'd0};

        end

        // A positive subnormal input reaches this branch.
        else begin

            // Simplified behavior: flush positive subnormal inputs to zero.
            // A fully compliant implementation would calculate their roots.
            result = 32'h00000000;

        end

    end


    // ========================================================================
    // STEP 4: HANDLE NEGATIVE NORMAL FINITE INPUTS
    // ========================================================================

    // At this point, the input is neither infinity nor NaN, and it is not
    // zero or subnormal. A set sign bit therefore indicates a negative
    // normal finite number.
    else if (sign_a) begin

        // The square root of a negative real number is not a real number.
        // Return a quiet NaN with a positive sign.
        result = {1'b0, 8'hFF, 1'b1, 22'd0};

    end


    // ========================================================================
    // STEP 5: PROCESS A POSITIVE NORMAL FINITE INPUT
    // ========================================================================

    // This branch handles positive, normalized, finite input values.
    else begin

        // Restore the implicit leading 1 in the normalized significand.
        //
        // IEEE-754 does not store this leading bit in fraction_a.
        // A normalized significand is represented as 1.fraction.
        significand = {1'b1, fraction_a};


        // Convert the biased exponent to an unbiased exponent.
        //
        // The concatenation adds three leading zeros so that exponent_a
        // is represented as an 11-bit unsigned quantity before subtraction.
        //
        //   unbiased_exp = exponent_a - 127
        //
        // The $signed conversion and signed destination allow negative
        // unbiased exponent values.
        unbiased_exp = $signed({3'b000, exponent_a}) - 11'sd127;


        // Initially, the adjusted exponent equals the original exponent.
        adjusted_exp = unbiased_exp;


        // ====================================================================
        // STEP 6: MAKE THE EXPONENT EVEN
        // ====================================================================

        // A square root halves the exponent:
        //
        //   sqrt(M * 2^E) = sqrt(M) * 2^(E/2)
        //
        // Integer division by two is simplest when E is even.
        // If the exponent is odd, multiply M by two and subtract one from E:
        //
        //   M * 2^E = (2*M) * 2^(E-1)
        //
        // Now E-1 is even, so:
        //
        //   sqrt(M * 2^E) = sqrt(2*M) * 2^((E-1)/2)
        if (unbiased_exp[0] == 1'b1) begin

            // Decrease an odd exponent by one to make it even.
            adjusted_exp = unbiased_exp - 11'sd1;


            // Scale the significand by an additional factor of two.
            // Shifting the 24-bit significand left by 24 positions is
            // equivalent to multiplying it by 2^24.
            //
            // The resulting radicand provides the integer square-root
            // datapath with the required scaling for this exponent parity.
            radicand = {24'd0, significand} << 24;

        end

        // The unbiased exponent is already even.
        else begin

            // Scale the significand by 2^23.
            // This is the corresponding radicand scaling for an even exponent.
            radicand = {24'd0, significand} << 23;

        end


        // ====================================================================
        // STEP 7: INITIALIZE THE INTEGER SQUARE-ROOT ALGORITHM
        // ====================================================================

        // Clear the partial remainder before processing the radicand.
        remainder = 26'd0;


        // Clear the root accumulator.
        // Each iteration appends one calculated root bit.
        root = 24'd0;


        // ====================================================================
        // STEP 8: CALCULATE THE INTEGER SQUARE ROOT
        // ====================================================================

        // Process 24 two-bit groups, starting with the most significant pair.
        //
        // i = 23 selects radicand bits 47:46.
        // i = 22 selects radicand bits 45:44.
        // ...
        // i = 0 selects radicand bits 1:0.
        //
        // Each iteration calculates one additional bit of the square root.
        for (i = 23; i >= 0; i = i - 1) begin

            // Extract the current two-bit group from the radicand.
            //
            // Shifting right by (i*2) moves the selected pair to bits 1:0.
            // The bitwise AND removes all other bits.
            next_pair = (radicand >> (i * 2)) & 2'b11;


            // Bring the next two-bit group into the partial remainder.
            //
            // Shifting the previous remainder left by two creates space
            // for the next pair, which is then inserted into the low bits.
            remainder = (remainder << 2) | next_pair;


            // Construct the trial value used by the digit-by-digit
            // integer square-root algorithm.
            //
            // The current root is shifted left by two positions and
            // the low bit is set to one.
            //
            // This trial value determines whether the next root bit
            // can be set to one without making the partial remainder negative.
            trial = ({2'b00, root} << 2) | 26'd1;


            // Compare the partial remainder against the trial value.
            if (remainder >= trial) begin

                // Subtract the trial value because the next root bit is 1.
                remainder = remainder - trial;


                // Shift the accumulated root left and append a 1 bit.
                root = (root << 1) | 24'd1;

            end

            // If the remainder is smaller than the trial value,
            // the next root bit must be zero.
            else begin

                // Shift the root left and append a 0 bit.
                root = root << 1;

            end

        end


        // ====================================================================
        // STEP 9: CALCULATE THE OUTPUT EXPONENT
        // ====================================================================

        // The adjusted exponent is even.
        // Divide it by two, then add the binary32 exponent bias of 127.
        //
        // The arithmetic right-shift operator >>> preserves the sign
        // of the signed exponent value.
        output_exp = (adjusted_exp >>> 1) + 11'sd127;


        // ====================================================================
        // STEP 10: CHECK EXPONENT OVERFLOW AND UNDERFLOW
        // ====================================================================

        // A binary32 biased exponent of 255 is reserved for infinity and NaN.
        // If the calculated exponent reaches or exceeds 255, return infinity.
        if (output_exp >= 11'sd255) begin

            // Encode positive infinity.
            // Sign = 0, exponent = 255, fraction = 0.
            result = {1'b0, 8'hFF, 23'd0};

        end

        // A biased exponent less than or equal to zero cannot represent
        // a positive normal binary32 value.
        else if (output_exp <= 11'sd0) begin

            // Simplified underflow behavior: return positive zero.
            // Subnormal output values are not generated.
            result = 32'h00000000;

        end

        // The output exponent is within the supported normal range.
        else begin

            // Assemble the final binary32 result.
            //
            // Bit 31     : Sign = 0, because this branch handles positive input.
            // Bits 30:23 : Calculated biased exponent.
            // Bits 22:0  : Lower 23 bits of the integer square-root result.
            //
            // The leading significand bit is implicit for normalized values.
            // No rounding is applied; the calculated significand is truncated.
            result = {1'b0, output_exp[7:0], root[22:0]};

        end

    // End of the positive normal finite input branch.
    end

// End of the combinational square-root logic.
end


// ============================================================================
// END OF MODULE
// ============================================================================

// Marks the end of the fp32_sqrt module.
endmodule