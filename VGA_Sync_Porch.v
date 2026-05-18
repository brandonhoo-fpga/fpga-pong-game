// ============================================================================
// File Name   : VGA_Sync_Porch.v
// Author      : Brandon Hoo
// Description : VGA front porch and sync pulse generator. Adds the standard
//               horizontal and vertical sync timing required by VGA monitors,
//               and gates RGB video to black during the blanking period.
//               Produces the final HSync, VSync, and RGB signals that drive
//               the physical VGA connector. Pixel position is taken in
//               directly from VGA_Sync_Pulses.
// ============================================================================

module VGA_Sync_Porch #(
    parameter VIDEO_WIDTH = 3,          // Bits per RGB channel
    parameter TOTAL_COLS = 800,
    parameter TOTAL_ROWS = 525,
    parameter ACTIVE_COLS = 640,
    parameter ACTIVE_ROWS = 480,
    parameter FRONT_PORCH_HORZ = 16,    // Pixels of black before HSync pulse
    parameter SYNC_PULSE_HORZ = 96,     // HSync pulse width in pixels
    parameter FRONT_PORCH_VERT = 10,    // Lines of black before VSync pulse
    parameter SYNC_PULSE_VERT = 2       // VSync pulse width in lines
  )
  (
   input                    i_Clk,
   input [9:0]              i_Col_Count,        // Current pixel column from VGA_Sync_Pulses
   input [9:0]              i_Row_Count,        // Current pixel row from VGA_Sync_Pulses
   input                    i_HSync,            // Active-region sync from upstream
   input                    i_VSync,
   input [VIDEO_WIDTH-1:0]  i_Red_Video,        // RGB video from game logic
   input [VIDEO_WIDTH-1:0]  i_Grn_Video,
   input [VIDEO_WIDTH-1:0]  i_Blu_Video,
   output                   o_HSync,            // Final VGA-spec sync
   output                   o_VSync,
   output [VIDEO_WIDTH-1:0] o_Red_Video,        // RGB gated by active region
   output [VIDEO_WIDTH-1:0] o_Grn_Video,
   output [VIDEO_WIDTH-1:0] o_Blu_Video
   );

// Sync pulse start/end positions
localparam PULSE_BEGIN_HORZ = ACTIVE_COLS + FRONT_PORCH_HORZ;
localparam PULSE_END_HORZ = ACTIVE_COLS + FRONT_PORCH_HORZ + SYNC_PULSE_HORZ;
localparam PULSE_BEGIN_VERT = ACTIVE_ROWS + FRONT_PORCH_VERT;
localparam PULSE_END_VERT = ACTIVE_ROWS + FRONT_PORCH_VERT + SYNC_PULSE_VERT;


// Black out RGB during blanking
wire w_Video_Active;
assign w_Video_Active = (i_Col_Count < ACTIVE_COLS && i_Row_Count < ACTIVE_ROWS);

assign o_Red_Video = w_Video_Active ? i_Red_Video : 0;
assign o_Grn_Video = w_Video_Active ? i_Grn_Video : 0;
assign o_Blu_Video = w_Video_Active ? i_Blu_Video : 0;

// Sync low during pulse window (VGA standard polarity)
assign o_HSync = !(i_Col_Count >= PULSE_BEGIN_HORZ && i_Col_Count < PULSE_END_HORZ);
assign o_VSync = !(i_Row_Count >= PULSE_BEGIN_VERT && i_Row_Count < PULSE_END_VERT);

endmodule
