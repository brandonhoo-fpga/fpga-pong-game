// ============================================================================
// File Name   : Pong_Game.v
// Author      : Brandon Hoo
// Description : Core Pong game module. Houses the round/score FSM, instantiates
//               the two paddles and ball physics, and produces the pixel-level
//               drawing logic that lights paddles and ball as white on black.
//               Operates on a coarse "game grid" that is upscaled to VGA pixels
//               by c_GAME_SCALE.
// ============================================================================

module Pong_Game #(
    parameter VIDEO_WIDTH = 3,      // Bits per RGB channel
    parameter TOTAL_COLS = 800,     // VGA total columns including blanking
    parameter TOTAL_ROWS = 525,     // VGA total rows including blanking
    parameter ACTIVE_COLS = 640,    // VGA active display width
    parameter ACTIVE_ROWS = 480,    // VGA active display height
    parameter c_GAME_SCALE = 16     // Pixels per game-grid cell (power of 2)
)
(
    input       i_Clk,              // 25MHz pixel clock

    input       i_Paddle1_Up,       // Player 1 controls
    input       i_Paddle1_Down,
    input       i_Paddle2_Up,       // Player 2 controls
    input       i_Paddle2_Down,

    input       i_HSync,            // Sync signals from VGA pulse generator
    input       i_VSync,

    input       i_Start_Game,       // Pulse from UART to start a round

    input [9:0] i_Row_Count,        // Current pixel row from VGA timing
    input [9:0] i_Col_Count,        // Current pixel column from VGA timing

    output reg [3:0] o_P1_Points = 0,   // Score outputs to 7-seg displays
    output reg [3:0] o_P2_Points = 0,

    output reg  o_HSync = 0,            // Sync passthrough
    output reg  o_VSync = 0,
    output reg [VIDEO_WIDTH-1:0] o_Red_Video,
    output reg [VIDEO_WIDTH-1:0] o_Grn_Video,
    output reg [VIDEO_WIDTH-1:0] o_Blu_Video
);

// Paddle and ball geometry in game-grid units
parameter c_PADDLE_HEIGHT = 6;
parameter c_PADDLE_START_Y = 12;
parameter c_BALL_START_X = 20;
parameter c_BALL_START_Y = 15;
parameter c_GAME_HEIGHT = ACTIVE_ROWS >> $clog2(c_GAME_SCALE);  // 30 cells
parameter c_GAME_WIDTH = ACTIVE_COLS >> $clog2(c_GAME_SCALE);   // 40 cells
parameter c_PADDLE_SPEED = 1;
parameter c_BALL_SPEED_START = 0;

// Game state machine
parameter IDLE          = 3'b000;
parameter RUNNING       = 3'b001;
parameter POINT_CHECK   = 3'b010;
parameter NEXT_ROUND    = 3'b011;
parameter SERVE         = 3'b100;
parameter WINNER        = 3'b101;
parameter CLEANUP       = 3'b110;

reg [2:0] r_SM_Main = IDLE;

// Wires from sub-modules
wire [9:0] w_Paddle1_Y;
wire [9:0] w_Paddle2_Y;
wire [9:0] w_Ball_X;
wire [9:0] w_Ball_Y;
wire [1:0] w_Ball_Dir_X;
wire [1:0] w_Ball_Dir_Y;

// Frame tick: 1-cycle pulse on rising edge of VSync
reg r_VSync_Prev = 0;
wire w_Frame_Tick = (i_VSync == 1'b1 && r_VSync_Prev == 1'b0);

// Start-round: external UART pulse or FSM-issued serve
wire w_Start_Round = (i_Start_Game == 1 || r_Start_Round == 1);
reg r_Start_Round;

// Inter-round wait counter
reg [5:0] r_Next_Round_Wait = 0;

always @(posedge i_Clk)
  begin
    r_VSync_Prev <= i_VSync;
    o_VSync <= i_VSync;
    o_HSync <= i_HSync;
  end

// Player 1 paddle
Paddle_Move #(
    .PADDLE_HEIGHT(c_PADDLE_HEIGHT),
    .GAME_HEIGHT(c_GAME_HEIGHT),
    .START_Y(c_PADDLE_START_Y),
    .PADDLE_SPEED(c_PADDLE_SPEED)
    )
Paddle1_Move_Inst (
    .i_Clk(i_Clk),
    .i_Frame_Tick(w_Frame_Tick),
    .i_Paddle_Up(i_Paddle1_Up),
    .i_Paddle_Down(i_Paddle1_Down),
    .o_Paddle_Y(w_Paddle1_Y)
    );

// Player 2 paddle
Paddle_Move #(
    .PADDLE_HEIGHT(c_PADDLE_HEIGHT),
    .GAME_HEIGHT(c_GAME_HEIGHT),
    .START_Y(c_PADDLE_START_Y),
    .PADDLE_SPEED(c_PADDLE_SPEED)
    )
Paddle2_Move_Inst (
    .i_Clk(i_Clk),
    .i_Frame_Tick(w_Frame_Tick),
    .i_Paddle_Up(i_Paddle2_Up),
    .i_Paddle_Down(i_Paddle2_Down),
    .o_Paddle_Y(w_Paddle2_Y)
    );

// Ball physics
Ball_Move #(
    .GAME_HEIGHT(c_GAME_HEIGHT),
    .GAME_WIDTH(c_GAME_WIDTH),
    .PADDLE_HEIGHT(c_PADDLE_HEIGHT),
    .BALL_SPEED_START(c_BALL_SPEED_START),
    .START_X(c_BALL_START_X),
    .START_Y(c_BALL_START_Y)
    )
Ball_Move_Inst (
    .i_Clk(i_Clk),
    .i_Frame_Tick(w_Frame_Tick),
    .i_Start_Round(w_Start_Round),
    .i_Paddle1_Y(w_Paddle1_Y),
    .i_Paddle2_Y(w_Paddle2_Y),
    .o_Ball_X(w_Ball_X),
    .o_Ball_Y(w_Ball_Y)
    );

// Round / score FSM
always @(posedge i_Clk)
begin
    case (r_SM_Main)
    IDLE:
    begin
        if(i_Start_Game == 1)
        begin
            r_SM_Main <= RUNNING;
        end
    end

    RUNNING:
    begin
        if (w_Ball_X == 0)
            begin
            r_SM_Main <= POINT_CHECK;
            o_P2_Points <= o_P2_Points + 1;
            end

        else if (w_Ball_X == c_GAME_WIDTH - 1)
            begin
            r_SM_Main <= POINT_CHECK;
            o_P1_Points <= o_P1_Points + 1;
            end
    end

    // First to 5 wins
    POINT_CHECK:
    begin
        if (o_P1_Points == 5 || o_P2_Points == 5)
            r_SM_Main <= WINNER;
        else
            r_SM_Main <= NEXT_ROUND;
    end

    // Brief pause before serving (~63 frames)
    NEXT_ROUND:
    begin
        if (w_Frame_Tick == 1)
        begin
            if (r_Next_Round_Wait == 63)
            begin
                r_Next_Round_Wait <= 0;
                r_Start_Round <= 1;
                r_SM_Main <= SERVE;
            end
            else
            begin
                r_Next_Round_Wait <= r_Next_Round_Wait + 1;
                r_SM_Main <= NEXT_ROUND;
            end
        end
    end

    SERVE:
    begin
        r_Start_Round <= 0;
        r_SM_Main <= RUNNING;
    end

    // Match over: reset scores
    WINNER:
    begin
        o_P1_Points <= 0;
        o_P2_Points <= 0;

        r_SM_Main <= CLEANUP;
    end

    // Hook for future cleanup logic
    CLEANUP:
    begin
        r_SM_Main <= IDLE;
    end


    endcase

end


// Drawing region detectors (game-grid coords scaled by c_GAME_SCALE)
wire w_Draw_Paddle1;
wire w_Draw_Paddle2;
wire w_Draw_Ball;

assign w_Draw_Paddle1 = (i_Col_Count >= 0) &&
                        (i_Col_Count < c_GAME_SCALE) &&
                        (i_Row_Count >= w_Paddle1_Y << $clog2(c_GAME_SCALE)) &&
                        (i_Row_Count < (w_Paddle1_Y + c_PADDLE_HEIGHT) << $clog2(c_GAME_SCALE));

assign w_Draw_Paddle2 = (i_Col_Count >= (c_GAME_WIDTH - 1) << $clog2(c_GAME_SCALE)) &&
                        (i_Col_Count < c_GAME_WIDTH << $clog2(c_GAME_SCALE)) &&
                        (i_Row_Count >= w_Paddle2_Y << $clog2(c_GAME_SCALE)) &&
                        (i_Row_Count < (w_Paddle2_Y + c_PADDLE_HEIGHT) << $clog2(c_GAME_SCALE));

assign w_Draw_Ball =    (i_Col_Count >= w_Ball_X << $clog2(c_GAME_SCALE)) &&
                        (i_Col_Count < (w_Ball_X + 1) << $clog2(c_GAME_SCALE)) &&
                        (i_Row_Count >= w_Ball_Y << $clog2(c_GAME_SCALE)) &&
                        (i_Row_Count < (w_Ball_Y + 1) << $clog2(c_GAME_SCALE));


// White on object, black elsewhere
always @(posedge i_Clk) begin
    if (w_Draw_Paddle1 || w_Draw_Paddle2 || w_Draw_Ball) begin
        o_Red_Video <= {VIDEO_WIDTH{1'b1}};
        o_Grn_Video <= {VIDEO_WIDTH{1'b1}};
        o_Blu_Video <= {VIDEO_WIDTH{1'b1}};
    end else begin
        o_Red_Video <= 0;
        o_Grn_Video <= 0;
        o_Blu_Video <= 0;
    end
end

endmodule
