// ============================================================================
// File Name   : Ball_Move.v
// Author      : Brandon Hoo
// Description : Ball physics module for Pong. Handles movement, wall and paddle
//               collisions, randomized serve direction via a 16-bit LFSR, and
//               progressive speed-up as the rally length grows. Operates in
//               the coarse game-grid coordinate system, advancing one step per
//               frame tick (gated by the speed counter).
// ============================================================================

module Ball_Move #(
    parameter GAME_HEIGHT = 30,
    parameter GAME_WIDTH = 40,
    parameter PADDLE_HEIGHT = 6,
    parameter BALL_SPEED_START = 0,
    parameter START_X = 20,
    parameter START_Y = 15
)
(
    input               i_Clk,
    input               i_Frame_Tick,           // 1-cycle pulse at start of each frame
    input [9:0]         i_Paddle1_Y,            // Player 1 paddle top position
    input [9:0]         i_Paddle2_Y,            // Player 2 paddle top position
    input               i_Start_Round,          // Re-spawn ball at center
    output reg [9:0]    o_Ball_X = START_X,     // Ball X in game-grid units
    output reg [9:0]    o_Ball_Y = START_Y      // Ball Y in game-grid units
);

    // Direction: 0 = decreasing, 1 = increasing, 2 = stopped
    reg [1:0] r_Ball_Dir_X = 2;
    reg [1:0] r_Ball_Dir_Y = 2;

    // Speed gate: lower r_Ball_Speed = slower ball
    reg [1:0] r_Ball_Speed_Count = 3;

    // Rally length, drives speed-up
    reg [3:0] r_Bounce_Count = 0;

    reg [1:0] r_Ball_Speed = BALL_SPEED_START;

    // 16-bit Fibonacci LFSR (taps 16,14,13,11)
    reg [15:0] r_LFSR = 16'h8888;

    // Paddle divided into thirds for variable bounce angles
    parameter PADDLE_SECTION = PADDLE_HEIGHT/3;

    // Free-running LFSR seeds new round directions from the low bits
    always @(posedge i_Clk)
    begin
        r_LFSR <= { r_LFSR[14:0], r_LFSR[15] ^ r_LFSR[13] ^ r_LFSR[12] ^ r_LFSR[10] };
    end


    always @ (posedge i_Clk)
    begin

        // New round: respawn ball, randomize direction
        if (i_Start_Round == 1)
        begin
            o_Ball_X <= START_X;
            o_Ball_Y <= START_Y;
            r_Ball_Dir_X <= r_LFSR[1];
            r_Ball_Dir_Y <= r_LFSR[0];
            r_Bounce_Count <= 0;
            r_Ball_Speed <= BALL_SPEED_START;
        end

        // Updates gated to ~60Hz frame tick
        if (i_Frame_Tick == 1)
        begin

            // Move only when speed counter matches target
            if(r_Ball_Speed_Count == r_Ball_Speed)
            begin

                r_Ball_Speed_Count <= 3;

                // Vertical movement and wall bounce
                if (r_Ball_Dir_Y == 0)
                begin
                    if (o_Ball_Y > 0)
                    begin
                        o_Ball_Y <= o_Ball_Y - 1;
                    end
                    else
                    begin
                        // Top wall hit: reflect downward
                        o_Ball_Y <= o_Ball_Y + 1;
                        r_Ball_Dir_Y <= 1;
                    end
                end

                else if (r_Ball_Dir_Y == 1)
                begin
                    if (o_Ball_Y < GAME_HEIGHT)
                    begin
                        o_Ball_Y <= o_Ball_Y + 1;
                    end
                    else
                    begin
                        // Bottom wall hit: reflect upward
                        o_Ball_Y <= o_Ball_Y - 1;
                        r_Ball_Dir_Y <= 0;
                    end
                end

                // Horizontal movement and paddle interaction
                // Moving left (toward Player 1)
                if (r_Ball_Dir_X == 0)
                begin
                    if (o_Ball_X > 1)
                    begin
                        o_Ball_X <= o_Ball_X - 1;
                    end
                    else if (o_Ball_X == 1)
                    begin
                        // Top third: reflect upward-right
                        if ((o_Ball_Y >= i_Paddle1_Y) && (o_Ball_Y < i_Paddle1_Y + PADDLE_SECTION))
                        begin
                            o_Ball_X <= o_Ball_X + 1;
                            r_Ball_Dir_X <= 1;
                            o_Ball_Y <= o_Ball_Y - 1;
                            r_Ball_Dir_Y <= 0;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Middle third: reflect straight right
                        else if ((o_Ball_Y >= i_Paddle1_Y + PADDLE_SECTION) && (o_Ball_Y < i_Paddle1_Y + (PADDLE_SECTION << 1)))
                        begin
                            o_Ball_X <= o_Ball_X + 1;
                            r_Ball_Dir_X<= 1;
                            o_Ball_Y <= o_Ball_Y;
                            r_Ball_Dir_Y <= 2;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Bottom third: reflect downward-right
                        else if ((o_Ball_Y >= i_Paddle1_Y + (PADDLE_SECTION << 1)) && (o_Ball_Y < i_Paddle1_Y + PADDLE_HEIGHT))
                        begin
                            o_Ball_X <= o_Ball_X + 1;
                            r_Ball_Dir_X <= 1;
                            o_Ball_Y <= o_Ball_Y + 1;
                            r_Ball_Dir_Y <= 1;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Missed paddle: drift off-screen, FSM scores
                        else
                        begin
                            o_Ball_X <= o_Ball_X - 1;
                            r_Ball_Dir_X <= 2;
                            r_Ball_Dir_Y <= 2;
                        end
                    end
                end

                // Moving right (toward Player 2)
                else if (r_Ball_Dir_X == 1)
                begin
                    if (o_Ball_X < GAME_WIDTH - 2)
                    begin
                        o_Ball_X <= o_Ball_X + 1;
                    end

                    else if (o_Ball_X == GAME_WIDTH - 2)
                    begin
                        // Top third: reflect upward-left
                        if ((o_Ball_Y >= i_Paddle2_Y) && (o_Ball_Y < i_Paddle2_Y + PADDLE_SECTION))
                        begin
                            o_Ball_X <= o_Ball_X - 1;
                            r_Ball_Dir_X <= 0;
                            o_Ball_Y <= o_Ball_Y - 1;
                            r_Ball_Dir_Y <= 0;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Middle third: reflect straight left
                        else if ((o_Ball_Y >= i_Paddle2_Y + PADDLE_SECTION) && (o_Ball_Y < i_Paddle2_Y + (PADDLE_SECTION << 1)))
                        begin
                            o_Ball_X <= o_Ball_X - 1;
                            r_Ball_Dir_X <= 0;
                            o_Ball_Y <= o_Ball_Y;
                            r_Ball_Dir_Y <= 2;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Bottom third: reflect downward-left
                        else if ((o_Ball_Y >= i_Paddle2_Y + (PADDLE_SECTION << 1)) && (o_Ball_Y < i_Paddle2_Y + PADDLE_HEIGHT))
                        begin
                            o_Ball_X <= o_Ball_X - 1;
                            r_Ball_Dir_X <= 0;
                            o_Ball_Y <= o_Ball_Y + 1;
                            r_Ball_Dir_Y <= 1;
                            if (r_Bounce_Count < 15)
                                r_Bounce_Count <= r_Bounce_Count + 1;
                        end

                        // Missed paddle: drift off-screen, FSM scores
                        else
                        begin
                            o_Ball_X <= o_Ball_X + 1;
                            r_Ball_Dir_X <= 2;
                            r_Ball_Dir_Y <= 2;
                        end

                    end
                end

                // Speed-up curve: every 8 bounces
                if (r_Bounce_Count < 8)
                    r_Ball_Speed <= BALL_SPEED_START;
                else if (r_Bounce_Count < 15)
                    r_Ball_Speed <= BALL_SPEED_START + 1;
                else
                    r_Ball_Speed <= BALL_SPEED_START + 2;


            end

            // Wait, decrement gate
            else
                r_Ball_Speed_Count <= r_Ball_Speed_Count - 1;
        end
    end

endmodule
