// ============================================================================
// File Name   : Binary_to_7Seg.v
// Author      : Brandon Hoo
// Description : Combinational decoder that converts a 4-bit binary value into
//               the seven segment drive pattern for hex digits 0-F. Used to
//               display each player's score on the Go Board's 7-segment LEDs.
//               Active-low segment outputs (0 = lit).
// ============================================================================

module Binary_to_7Seg (
    input[3:0] i_Binary,        // 4-bit value to display (0-F)
    output o_Segment_A,
    output o_Segment_B,
    output o_Segment_C,
    output o_Segment_D,
    output o_Segment_E,
    output o_Segment_F,
    output o_Segment_G
);

reg[6:0] r_7SEG;

// Hex digit to segment LUT
always@(*)
begin
case(i_Binary)
    4'b0000 : r_7SEG = 7'b0000001;  // '0'
    4'b0001 : r_7SEG = 7'b1001111;  // '1'
    4'b0010 : r_7SEG = 7'b0010010;  // '2'
    4'b0011 : r_7SEG = 7'b0000110;  // '3'
    4'b0100 : r_7SEG = 7'b1001100;  // '4'
    4'b0101 : r_7SEG = 7'b0100100;  // '5'
    4'b0110 : r_7SEG = 7'b0100000;  // '6'
    4'b0111 : r_7SEG = 7'b0001111;  // '7'
    4'b1000 : r_7SEG = 7'b0000000;  // '8'
    4'b1001 : r_7SEG = 7'b0000100;  // '9'
    4'b1010 : r_7SEG = 7'b0001000;  // 'A'
    4'b1011 : r_7SEG = 7'b1100000;  // 'b'
    4'b1100 : r_7SEG = 7'b0110001;  // 'C'
    4'b1101 : r_7SEG = 7'b1000010;  // 'd'
    4'b1110 : r_7SEG = 7'b0110000;  // 'E'
    4'b1111 : r_7SEG = 7'b0111000;  // 'F'

    default: r_7SEG = 7'b0000000;   // All segments lit (fallback)

endcase
end

// Drive segment outputs
assign o_Segment_A = r_7SEG[6];
assign o_Segment_B = r_7SEG[5];
assign o_Segment_C = r_7SEG[4];
assign o_Segment_D = r_7SEG[3];
assign o_Segment_E = r_7SEG[2];
assign o_Segment_F = r_7SEG[1];
assign o_Segment_G = r_7SEG[0];

endmodule
