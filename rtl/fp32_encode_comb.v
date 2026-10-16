// ============================================================================
// Project   : Floating-Point Logic Unit (FLU)
// File      : fp32_encode_comb.v
// Developer : Ghulam Yaseen Nangraj
// Date      : 2026-10-16
// Platform  : Xilinx Vivado v2025.2.1 / Verilog HDL
//
// Purpose:
//   Converts a decimal number supplied as an integer part and a fractional
//   part into a 32-bit IEEE-754 single-precision floating-point representation.
//
// Input Interpretation:
//   value = (-1)^sign * (whole + fraction / 10^fractional_digits)
//
//   sign = 0 : Positive number
//   sign = 1 : Negative number
//
//   fractional_digits = 0 : Ignore fraction and use whole only.
//   fractional_digits = 1 : Fraction is divided by 10.
//   fractional_digits = 2 : Fraction is divided by 100.
//   ...
//   fractional_digits = 9 : Fraction is divided by 1,000,000,000.
//
// Examples:
//   whole=23, fraction=127, digits=3, sign=0 -> +23.127
//   whole=23, fraction=127, digits=3, sign=1 -> -23.127
//   whole=0,  fraction=5,   digits=1, sign=0 -> +0.5
//
// IEEE-754 Binary32 Format:
//   Bit 31     : Sign
//   Bits 30:23 : 8-bit biased exponent
//   Bits 22:0  : 23-bit fraction field
//
// Implementation:
//   - Uses Q40 fixed-point arithmetic as an intermediate representation.
//   - Q40 means that the fixed-point integer represents a value multiplied
//     by 2^40.
//   - Searches for the most significant set bit to normalize the number.
//   - Uses round-to-nearest, ties-to-even for the retained significand bits.
//   - Uses combinational logic; no clock or reset is required.
//
// Limitations:
//   - Decimal division is truncated at Q40 precision.
//   - Correct rounding is therefore not guaranteed for every possible input.
//   - Fractional digit counts above 9 produce positive zero in this version.
//   - Complete IEEE-754 handling of subnormal numbers, overflow, infinity,
//     and NaN is not implemented.
//   - The implementation is intended as an educational baseline.
// ============================================================================


// Simulation time unit: 1 nanosecond.
// Simulation time precision: 1 picosecond.
`timescale 1ns / 1ps


// ============================================================================
// MODULE DECLARATION AND INPUT/OUTPUT PORTS
// ============================================================================

module fp32_encode (

    // Sign bit of the decimal input.
    // 0 represents a positive number; 1 represents a negative number.
    input wire sign,

    // Unsigned 32-bit integer part of the decimal input.
    // Example: whole = 32'd23 represents the integer part 23.
    input wire [31:0] whole,

    // Unsigned 32-bit fractional digits.
    // Example: fraction = 32'd127 with three decimal places represents 0.127.
    input wire [31:0] fraction,

    // Number of decimal places used to scale the fractional input.
    // Supported values are 0 through 9.
    input wire [3:0] fractional_digits,

    // Final 32-bit IEEE-754 single-precision encoded result.
    // The output is driven by the continuous assignment below.
    output wire [31:0] result
);


// ============================================================================
// SECTION 1: FIXED-POINT CONVERSION REGISTERS
// ============================================================================

// Stores the decimal scaling factor 10^fractional_digits.
// Examples:
//   1 digit -> 10
//   2 digits -> 100
//   3 digits -> 1000
// The 64-bit width accommodates all supported scaling factors.
reg [63:0] decimal_scale;


// Stores the integer part multiplied by 2^40.
// The 72-bit width provides room for the 32-bit integer shifted left by 40.
reg [71:0] whole_scaled;


// Stores the fractional part converted into Q40 fixed-point form.
// It represents approximately:
//
//   fraction_scaled = (fraction / decimal_scale) * 2^40
//
// The fractional division may truncate the least significant bits.
reg [71:0] fraction_scaled;


// Stores the combined Q40 fixed-point value.
//
//   fixed_value = whole_scaled + fraction_scaled
//
// The sign is not included in this intermediate value; the number's sign
// is inserted later when constructing the IEEE-754 output.
reg [71:0] fixed_value;


// ============================================================================
// SECTION 2: NORMALIZATION AND ROUNDING REGISTERS
// ============================================================================

// Holds the significand bits used during normalization and rounding.
// The extra width allows the intermediate calculation to accommodate
// shifts and discarded-bit calculations.
reg [71:0] significand_work;


// Stores the portion of fixed_value discarded when shifting right.
// This remainder determines whether the significand should be rounded up.
reg [71:0] remainder_work;


// Stores half of the least significant retained-bit unit.
// Comparing remainder_work with half_work determines the rounding direction.
reg [71:0] half_work;


// Stores the rounded 24-bit significand, including one extra carry bit.
// IEEE-754 binary32 uses 24 bits of significand precision for normal numbers:
// one implicit leading bit and 23 explicitly stored fraction bits.
reg [24:0] rounded_significand;


// ============================================================================
// SECTION 3: IEEE-754 OUTPUT-FIELD REGISTERS
// ============================================================================

// Temporary 32-bit register containing the assembled IEEE-754 result.
// The output wire result is continuously driven from this register.
reg [31:0] encoded_comb;


// Stores the 8-bit biased exponent field.
// For normal binary32 numbers:
//
//   biased exponent = unbiased exponent + 127
//
// This implementation does not fully handle exponent overflow or subnormals.
reg [7:0] exponent_field;


// Stores the 23-bit fraction field written into the IEEE-754 result.
// For normal numbers, the leading significand bit is implicit and omitted.
reg [22:0] fraction_field;


// Indicates whether the significand must be rounded upward.
// A value of 1 increments the retained significand by one.
reg round_up;


// Indicates that fractional_digits is outside the supported range 0..9.
// When asserted, this implementation outputs positive zero.
reg invalid_digits;


// ============================================================================
// SECTION 4: INTEGER VARIABLES USED FOR CALCULATIONS
// ============================================================================

// Index of the most significant set bit in fixed_value.
// A value of -1 is used initially to indicate that no set bit has been found.
integer msb_index;


// Number of bit positions needed to shift the fixed-point value so that
// the leading significand bit reaches bit position 23.
integer shift_amount;


// Exponent of the normalized value before adding the IEEE-754 bias of 127.
integer exponent_unbiased;


// Loop counter used to scan all 72 bits of fixed_value.
integer i;


// ============================================================================
// SECTION 5: CONNECT THE INTERNAL RESULT TO THE OUTPUT
// ============================================================================

// Continuously drives the module's output with the internally assembled
// IEEE-754 bit pattern.
// Because encoded_comb is assigned in an always @* block, the output changes
// whenever the combinational conversion logic updates encoded_comb.
assign result = encoded_comb;


// ============================================================================
// SECTION 6: COMBINATIONAL DECIMAL-TO-IEEE-754 CONVERSION
// ============================================================================

// This block performs the complete conversion whenever any input changes.
//
// The block:
//   1. Initializes all intermediate registers.
//   2. Determines the decimal scaling factor.
//   3. Converts the decimal input to Q40 fixed-point form.
//   4. Finds the most significant set bit.
//   5. Calculates the exponent.
//   6. Normalizes and rounds the significand.
//   7. Assembles the IEEE-754 output.
//
// Every register assigned in this block receives a default value to avoid
// unintended latch inference.
always @* begin


    // ========================================================================
    // STEP 1: INITIALIZE INTERMEDIATE REGISTERS
    // ========================================================================

    // Default decimal scaling factor is 1.
    // This corresponds to zero fractional decimal places.
    decimal_scale = 64'd1;


    // Initialize the scaled integer part to zero.
    whole_scaled = 72'd0;


    // Initialize the scaled fractional part to zero.
    fraction_scaled = 72'd0;


    // Initialize the combined fixed-point value to zero.
    fixed_value = 72'd0;


    // Clear the intermediate significand.
    significand_work = 72'd0;


    // Clear the discarded-bit remainder.
    remainder_work = 72'd0;


    // Clear the half-way rounding threshold.
    half_work = 72'd0;


    // Initialize the rounded significand to zero.
    rounded_significand = 25'd0;


    // Initialize the encoded output as signed zero.
    // The requested sign is retained even when the numerical value is zero.
    // Example:
    //   sign = 0 -> 32'h00000000
    //   sign = 1 -> 32'h80000000
    encoded_comb = {sign, 31'd0};


    // Initialize the exponent field to zero.
    exponent_field = 8'd0;


    // Initialize the fraction field to zero.
    fraction_field = 23'd0;


    // Do not round upward unless the rounding logic requests it.
    round_up = 1'b0;


    // Assume the fractional digit count is valid until checked below.
    invalid_digits = 1'b0;


    // No most significant set bit has been found yet.
    msb_index = -1;


    // Initialize the normalization shift amount.
    shift_amount = 0;


    // Initialize the unbiased exponent.
    exponent_unbiased = 0;


    // ========================================================================
    // STEP 2: DETERMINE THE DECIMAL SCALING FACTOR
    // ========================================================================

    // Select 10^fractional_digits using a case statement.
    // This avoids using real-number arithmetic and keeps the conversion
    // suitable for synthesizable Verilog-2001.
    case (fractional_digits)

        // No fractional decimal places: divisor = 1.
        4'd0: decimal_scale = 64'd1;

        // One decimal place: divisor = 10.
        4'd1: decimal_scale = 64'd10;

        // Two decimal places: divisor = 100.
        4'd2: decimal_scale = 64'd100;

        // Three decimal places: divisor = 1000.
        4'd3: decimal_scale = 64'd1000;

        // Four decimal places: divisor = 10000.
        4'd4: decimal_scale = 64'd10000;

        // Five decimal places: divisor = 100000.
        4'd5: decimal_scale = 64'd100000;

        // Six decimal places: divisor = 1000000.
        4'd6: decimal_scale = 64'd1000000;

        // Seven decimal places: divisor = 10000000.
        4'd7: decimal_scale = 64'd10000000;

        // Eight decimal places: divisor = 100000000.
        4'd8: decimal_scale = 64'd100000000;

        // Nine decimal places: divisor = 1000000000.
        4'd9: decimal_scale = 64'd1000000000;


        // Any other value is unsupported.
        default: begin

            // Restore the safe default scaling factor.
            decimal_scale = 64'd1;

            // Mark the input as invalid.
            invalid_digits = 1'b1;

        end

    endcase


    // ========================================================================
    // STEP 3: CONVERT THE INTEGER PART TO Q40 FIXED-POINT FORM
    // ========================================================================

    // Prepend 40 zero bits to the 32-bit unsigned integer.
    // Then shift left by 40 bits.
    //
    // Mathematically:
    //
    //   whole_scaled = whole * 2^40
    //
    // Q40 representation allows integer and fractional components to be
    // combined using integer arithmetic.
    whole_scaled = {40'd0, whole} << 40;


    // ========================================================================
    // STEP 4: CONVERT THE FRACTIONAL PART TO Q40 FIXED-POINT FORM
    // ========================================================================

    // When fractional_digits is zero, the fraction input is deliberately
    // ignored. This makes the input value equal to whole.
    if (fractional_digits == 4'd0) begin

        // Set the scaled fractional contribution to zero.
        fraction_scaled = 72'd0;

    end

    // If the digit count is supported, scale the fraction to Q40.
    else if (!invalid_digits) begin

        // First shift fraction left by 40 bits, multiplying it by 2^40.
        // Then divide by 10^fractional_digits.
        //
        // Mathematically:
        //
        //   fraction_scaled =
        //       (fraction * 2^40) / (10^fractional_digits)
        //
        // Integer division truncates any remaining fractional bits.
        fraction_scaled = ({40'd0, fraction} << 40) / decimal_scale;

    end


    // ========================================================================
    // STEP 5: COMBINE THE INTEGER AND FRACTIONAL PARTS
    // ========================================================================

    // Add the two Q40 components to form the complete magnitude.
    //
    //   fixed_value = (whole + fraction / decimal_scale) * 2^40
    //
    // This is an unsigned magnitude; the sign is applied during final packing.
    fixed_value = whole_scaled + fraction_scaled;


    // ========================================================================
    // STEP 6: HANDLE INVALID DIGIT COUNTS AND ZERO
    // ========================================================================

    // Check whether the fractional digit count is outside 0..9.
    if (invalid_digits) begin

        // Unsupported digit counts produce positive zero in this version.
        encoded_comb = 32'h00000000;

    end

    // Check whether the converted numerical magnitude is zero.
    else if (fixed_value == 72'd0) begin

        // IEEE-754 supports both positive zero and negative zero.
        // Preserve the input sign when the converted magnitude is zero.
        encoded_comb = {sign, 31'd0};

    end

    // Continue with normalization and encoding for nonzero valid inputs.
    else begin


        // ====================================================================
        // STEP 7: FIND THE MOST SIGNIFICANT SET BIT
        // ====================================================================

        // Scan every bit of the 72-bit fixed-point value.
        // Each time a set bit is found, record its index.
        //
        // Because the loop runs from bit 0 to bit 71, the final recorded
        // index is the position of the most significant set bit.
        for (i = 0; i < 72; i = i + 1) begin

            // Test whether the current bit is 1.
            if (fixed_value[i])

                // Record the current bit position.
                msb_index = i;

        end


        // ====================================================================
        // STEP 8: CALCULATE THE UNBIASED AND BIASED EXPONENTS
        // ====================================================================

        // Q40 values are scaled by 2^40.
        // If the most significant bit is at index msb_index, the corresponding
        // unbiased exponent is:
        //
        //   exponent_unbiased = msb_index - 40
        //
        // For example, the value 1.5 has an unbiased exponent of 0.
        exponent_unbiased = msb_index - 40;


        // IEEE-754 binary32 stores the exponent with a bias of 127.
        //
        //   exponent_field = exponent_unbiased + 127
        //
        // This calculation assumes that the value can be represented as
        // a normal binary32 number.
        exponent_field = exponent_unbiased + 127;


        // Calculate the shift needed to position the leading set bit at
        // bit 23, producing a 24-bit significand including the implicit bit.
        //
        // A positive shift_amount means shift right.
        // A zero or negative value means no right shift is needed.
        shift_amount = msb_index - 23;


        // ====================================================================
        // STEP 9: NORMALIZE THE SIGNIFICAND AND CALCULATE ROUNDING INFORMATION
        // ====================================================================

        // If the value has more than 24 significant bits in its Q40
        // representation, shift right to retain the leading 24 bits.
        if (shift_amount > 0) begin

            // Retain the upper bits after shifting right.
            significand_work = fixed_value >> shift_amount;


            // Reconstruct the retained portion at its original bit positions
            // and subtract it from fixed_value.
            // The difference contains the discarded bits.
            remainder_work =
                fixed_value - (significand_work << shift_amount);


            // Calculate half of one discarded-bit unit.
            //
            //   half_work = 2^(shift_amount - 1)
            //
            // The remainder is compared with this value to decide rounding.
            half_work = 72'd1 << (shift_amount - 1);


            // ---------------------------------------------------------------
            // ROUND-TO-NEAREST, TIES-TO-EVEN
            // ---------------------------------------------------------------

            // If the discarded portion is greater than half, round upward.
            if (remainder_work > half_work)

                // Increment the retained significand in the next calculation.
                round_up = 1'b1;


            // If the discarded portion is exactly half, round upward only
            // when the retained significand is odd.
            // This produces an even least significant retained bit.
            else if ((remainder_work == half_work) &&
                     significand_work[0])

                // Round upward to the next even significand.
                round_up = 1'b1;

            // Otherwise, round_up remains zero.
            // This includes values below half and exact ties with an even
            // retained significand.

        end

        // If shift_amount is zero or negative, shift left as necessary.
        // In this branch, no bits are discarded by the normalization shift.
        else begin

            // Move the leading bit to position 23.
            // A negative shift amount is converted to a positive left shift.
            significand_work = fixed_value << (-shift_amount);


            // No rounding increment is needed in this branch.
            round_up = 1'b0;

        end


        // ====================================================================
        // STEP 10: APPLY THE ROUNDING INCREMENT
        // ====================================================================

        // Extract the lower 24 bits of significand_work.
        // Add round_up:
        //   0 -> keep the retained significand unchanged.
        //   1 -> increment the retained significand by one.
        //
        // The 25-bit destination preserves a carry produced by rounding.
        rounded_significand =
            {1'b0, significand_work[23:0]} + round_up;


        // ====================================================================
        // STEP 11: HANDLE A ROUNDING CARRY
        // ====================================================================

        // Rounding may produce a carry into bit 24.
        // This occurs when the rounded significand becomes 10.000... in
        // normalized binary form rather than 1.000....
        if (rounded_significand[24]) begin

            // Shift right by one to restore the normalized significand.
            rounded_significand = rounded_significand >> 1;


            // Increase the exponent to account for the extra factor of two.
            exponent_field = exponent_field + 1'b1;

        end


        // ====================================================================
        // STEP 12: EXTRACT THE IEEE-754 FRACTION FIELD
        // ====================================================================

        // Store bits 22:0 of the rounded significand in the fraction field.
        //
        // For normal binary32 numbers, the leading significand bit is
        // implicitly 1 and is not stored in the 23-bit fraction field.
        fraction_field = rounded_significand[22:0];


        // ====================================================================
        // STEP 13: ASSEMBLE THE FINAL IEEE-754 BINARY32 RESULT
        // ====================================================================

        // Concatenate the three IEEE-754 fields:
        //
        //   Bit 31     : sign
        //   Bits 30:23 : biased exponent
        //   Bits 22:0  : fraction
        //
        // The result is the 32-bit IEEE-754 encoding of the input magnitude
        // with the requested sign.
        encoded_comb = {sign, exponent_field, fraction_field};


    // End of the nonzero, valid-input conversion branch.
    end


// End of the combinational conversion block.
end


// ============================================================================
// END OF MODULE
// ============================================================================

// Marks the end of the fp32_encode module.
endmodule