// ============================================================================
// File Name   : Paddle_Move.v
// Author      : Brandon Hoo
// Description : Paddle movement controller. Moves the paddle one game-grid
//               cell up or down per gated frame tick while the corresponding
//               input is held, clamped to the top and bottom of the play area.
//               PADDLE_SPEED sets how many frames between movement steps.
// ============================================================================

module Paddle_Move #(
    parameter PADDLE_HEIGHT = 6,    // Paddle height in game-grid cells
    parameter GAME_HEIGHT = 30,     // Vertical play area in game-grid cells
    parameter START_Y = 12,         // Initial Y position
    parameter PADDLE_SPEED = 1      // Lower = slower
)
(
    input               i_Clk,
    input               i_Frame_Tick,           // 1-cycle pulse per VGA frame
    input               i_Paddle_Up,            // Up control (debounced)
    input               i_Paddle_Down,          // Down control (debounced)
    output reg [9:0]    o_Paddle_Y = START_Y    // Paddle top position
);

// Speed gate counter
reg [1:0] r_Paddle_Speed_Count = 3;

    always @ (posedge i_Clk)
    begin
        if (i_Frame_Tick == 1)
        begin
            // Move when gate matches
            if (r_Paddle_Speed_Count == PADDLE_SPEED)
            begin

                r_Paddle_Speed_Count <= 3;

                // Up has priority if both held
                if (i_Paddle_Up == 1 && o_Paddle_Y > 0)
                        o_Paddle_Y <= o_Paddle_Y - 1;
                else if (i_Paddle_Down == 1 && (o_Paddle_Y + PADDLE_HEIGHT) < GAME_HEIGHT)
                        o_Paddle_Y <= o_Paddle_Y + 1;
            end

            // Hold position, decrement gate
            else
            begin
                o_Paddle_Y <= o_Paddle_Y;
                r_Paddle_Speed_Count <= r_Paddle_Speed_Count - 1;
            end
        end
    end

endmodule
