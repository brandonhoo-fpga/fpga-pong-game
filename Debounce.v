// ============================================================================
// File Name   : Debounce.v
// Author      : Brandon Hoo
// Description : State-based debouncer for mechanical switches. Filters out
//               mechanical bounce by requiring the input to remain stable for
//               c_DEBOUNCE_LIMIT clock cycles before the output is updated.
//               Includes a two-stage synchronizer for the async switch input.
//
//               Note: Default limit (250,000) gives a 10ms delay at 25MHz.
// ============================================================================

module Debounce (
    input i_Clk,    // 25MHz system clock
    input i_Switch, // Switch Input
    output o_Switch // Switch Output
);

// 25MHz clock = 40ns per clock cycle
// 10ms / 40ns = 250000 cycles = c_DEBOUNCE_LIMIT
parameter c_DEBOUNCE_LIMIT = 250000;

// 18-bit counter -> 2^18 = 262,144
reg[17:0] r_Count = 0;
reg r_State = 1'b0;

// Two-stage Synchronizer
reg r_Sync_0 = 1'b1;
reg r_Sync_1 = 1'b1;

always @(posedge i_Clk)
begin
    // Synchronize the asynchronous input
    r_Sync_0 <= i_Switch;
    r_Sync_1 <= r_Sync_0;

    // Synchronized input differs from r_State, increment counter
    if (r_Sync_1 != r_State && r_Count < c_DEBOUNCE_LIMIT)
    r_Count <= r_Count + 1;

    // Limit reached, apply valid state change and reset count
    else if (r_Count == c_DEBOUNCE_LIMIT)
    begin
    r_State <= r_Sync_1;
    r_Count <= 0;
    end

    // No switch activity, reset counter
    else
    r_Count <= 0;
end

// Drives the output port with the debounced register state
assign o_Switch = r_State;

endmodule
