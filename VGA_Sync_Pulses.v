// ============================================================================
// File Name   : VGA_Sync_Pulses.v
// Author      : Brandon Hoo
// Description : VGA timing generator. Produces row and column counters for the
//               full 800x525 frame at a 25MHz pixel clock (640x480 @ 60Hz),
//               and outputs active-region "display enable" sync signals that
//               are high while the beam is inside the visible 640x480 area.
//               Actual front porch / sync pulses are produced downstream by
//               VGA_Sync_Porch.
// ============================================================================

module VGA_Sync_Pulses #(
    parameter TOTAL_COLS = 800,     // Total columns including blanking
    parameter TOTAL_ROWS = 525,     // Total rows including blanking
    parameter ACTIVE_COLS = 640,    // Visible columns
    parameter ACTIVE_ROWS = 480     // Visible rows
  )
  (
   input            i_Clk,                  // 25MHz pixel clock
   output           o_HSync,                // High during active columns
   output           o_VSync,                // High during active rows
   output reg [9:0] o_Col_Count = 0,        // Current pixel column
   output reg [9:0] o_Row_Count = 0         // Current pixel row
   );

// Beam sweep: column then row, wraps at frame end
always @(posedge i_Clk)
begin
    if (o_Col_Count < TOTAL_COLS - 1)
        o_Col_Count <= o_Col_Count + 1;
    else
        begin
        if (o_Row_Count < TOTAL_ROWS - 1)
            o_Row_Count <= o_Row_Count + 1;
        else
            o_Row_Count <= 0;
        o_Col_Count <= 0;
        end
end

// Active-region indicators
assign o_HSync = (o_Col_Count < ACTIVE_COLS) ? 1'b1 : 1'b0;
assign o_VSync = (o_Row_Count < ACTIVE_ROWS) ? 1'b1 : 1'b0;

endmodule
