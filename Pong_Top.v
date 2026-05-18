// ============================================================================
// File Name   : Pong_Top.v
// Author      : Brandon Hoo
// Description : Top-level module for the FPGA Pong game. Integrates the four
//               debouncers, UART receiver (used to start the round), the dual
//               7-segment score displays, the VGA timing generators, and the
//               core Pong_Game module that handles paddle/ball logic.
// ============================================================================

module main(
    input i_Clk,                // 25MHz System Clock

    input i_Switch_1,           // Player 1 Up
    input i_Switch_2,           // Player 1 Down
    input i_Switch_3,           // Player 2 Up
    input i_Switch_4,           // Player 2 Down

    input i_UART_RX,            // Serial start-game signal from PC

    // Player 1 score 7-segment display
    output o_Segment1_A,
    output o_Segment1_B,
    output o_Segment1_C,
    output o_Segment1_D,
    output o_Segment1_E,
    output o_Segment1_F,
    output o_Segment1_G,

    // Player 2 score 7-segment display
    output o_Segment2_A,
    output o_Segment2_B,
    output o_Segment2_C,
    output o_Segment2_D,
    output o_Segment2_E,
    output o_Segment2_F,
    output o_Segment2_G,

    // VGA video and sync outputs (3-bit color per channel)
    output o_VGA_HSync,
    output o_VGA_VSync,
    output o_VGA_Red_0,
    output o_VGA_Red_1,
    output o_VGA_Red_2,
    output o_VGA_Grn_0,
    output o_VGA_Grn_1,
    output o_VGA_Grn_2,
    output o_VGA_Blu_0,
    output o_VGA_Blu_1,
    output o_VGA_Blu_2
);

// VGA 640x480 @ 60Hz timing
parameter c_VIDEO_WIDTH = 3;
parameter c_TOTAL_COLS = 800;
parameter c_TOTAL_ROWS = 525;
parameter c_ACTIVE_COLS = 640;
parameter c_ACTIVE_ROWS = 480;

wire w_RX_DV;

// Video pipeline wires (Game = from game core, Porch = post-porch)
wire [c_VIDEO_WIDTH-1:0] w_Red_Video_Game, w_Red_Video_Porch;
wire [c_VIDEO_WIDTH-1:0] w_Grn_Video_Game, w_Grn_Video_Porch;
wire [c_VIDEO_WIDTH-1:0] w_Blu_Video_Game, w_Blu_Video_Porch;

wire [9:0] w_Row_Count;
wire [9:0] w_Col_Count;

wire w_HSync_Start, w_HSync_Game, w_HSync_Porch;
wire w_VSync_Start, w_VSync_Game, w_VSync_Porch;

wire w_Switch_1, w_Switch_2, w_Switch_3, w_Switch_4;

wire [3:0] w_P1_Points, w_P2_Points;

// Instantiation of Debounce Module for each player switch
Debounce Debounce_Switch_1
(.i_Clk(i_Clk),
.i_Switch(i_Switch_1),
.o_Switch(w_Switch_1)
);

Debounce Debounce_Switch_2
(.i_Clk(i_Clk),
.i_Switch(i_Switch_2),
.o_Switch(w_Switch_2)
);

Debounce Debounce_Switch_3
(.i_Clk(i_Clk),
.i_Switch(i_Switch_3),
.o_Switch(w_Switch_3)
);

Debounce Debounce_Switch_4
(.i_Clk(i_Clk),
.i_Switch(i_Switch_4),
.o_Switch(w_Switch_4)
);


// UART Receiver (Baud: 115200 | 25MHz / 115200 = 217 clks/bit)
// RX byte unused; only the data-valid pulse triggers a round
UART_RX #(.CLKS_PER_BIT(217)) UART_RX_Inst
(.i_Clock(i_Clk),
.i_RX_Serial(i_UART_RX),
.o_RX_DV(w_RX_DV),
.o_RX_Byte());

// 7-segment decoders for each player's score
Binary_to_7Seg SevenSeg1_Inst
(.i_Binary(w_P1_Points),
.o_Segment_A(o_Segment1_A),
.o_Segment_B(o_Segment1_B),
.o_Segment_C(o_Segment1_C),
.o_Segment_D(o_Segment1_D),
.o_Segment_E(o_Segment1_E),
.o_Segment_F(o_Segment1_F),
.o_Segment_G(o_Segment1_G)
);

Binary_to_7Seg SevenSeg2_Inst
(.i_Binary(w_P2_Points),
.o_Segment_A(o_Segment2_A),
.o_Segment_B(o_Segment2_B),
.o_Segment_C(o_Segment2_C),
.o_Segment_D(o_Segment2_D),
.o_Segment_E(o_Segment2_E),
.o_Segment_F(o_Segment2_F),
.o_Segment_G(o_Segment2_G)
);


// VGA timing generator (row/col counters and active-region sync)
VGA_Sync_Pulses #(
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Pulses_Inst (
    .i_Clk(i_Clk),
    .o_HSync(w_HSync_Start),
    .o_VSync(w_VSync_Start),
    .o_Col_Count(w_Col_Count),
    .o_Row_Count(w_Row_Count)
    );


// Core game logic
Pong_Game #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
Pong_Game_Inst (
    .i_Clk(i_Clk),
    .i_Paddle1_Up(w_Switch_1),
    .i_Paddle1_Down(w_Switch_2),
    .i_Paddle2_Up(w_Switch_3),
    .i_Paddle2_Down(w_Switch_4),
    .i_Start_Game(w_RX_DV),
    .i_HSync(w_HSync_Start),
    .i_VSync(w_VSync_Start),
    .i_Col_Count(w_Col_Count),
    .i_Row_Count(w_Row_Count),
    .o_P1_Points(w_P1_Points),
    .o_P2_Points(w_P2_Points),
    .o_HSync(w_HSync_Game),
    .o_VSync(w_VSync_Game),
    .o_Red_Video(w_Red_Video_Game),
    .o_Grn_Video(w_Grn_Video_Game),
    .o_Blu_Video(w_Blu_Video_Game)
    );

// Adds VGA-spec front porch and sync pulse timing
VGA_Sync_Porch #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Porch_Inst (
    .i_Clk(i_Clk),
    .i_Col_Count(w_Col_Count),
    .i_Row_Count(w_Row_Count),
    .i_HSync(w_HSync_Game),
    .i_VSync(w_VSync_Game),
    .i_Red_Video(w_Red_Video_Game),
    .i_Grn_Video(w_Grn_Video_Game),
    .i_Blu_Video(w_Blu_Video_Game),
    .o_HSync(w_HSync_Porch),
    .o_VSync(w_VSync_Porch),
    .o_Red_Video(w_Red_Video_Porch),
    .o_Grn_Video(w_Grn_Video_Porch),
    .o_Blu_Video(w_Blu_Video_Porch)
    );

// Drive the physical VGA outputs
assign o_VGA_HSync = w_HSync_Porch;
assign o_VGA_VSync = w_VSync_Porch;

assign o_VGA_Red_0 = w_Red_Video_Porch[0];
assign o_VGA_Red_1 = w_Red_Video_Porch[1];
assign o_VGA_Red_2 = w_Red_Video_Porch[2];

assign o_VGA_Grn_0 = w_Grn_Video_Porch[0];
assign o_VGA_Grn_1 = w_Grn_Video_Porch[1];
assign o_VGA_Grn_2 = w_Grn_Video_Porch[2];

assign o_VGA_Blu_0 = w_Blu_Video_Porch[0];
assign o_VGA_Blu_1 = w_Blu_Video_Porch[1];
assign o_VGA_Blu_2 = w_Blu_Video_Porch[2];

endmodule
