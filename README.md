# FPGA Pong Game (VGA Output)
A two-player Pong game implemented entirely in hardware on an FPGA. Drives a 640x480 @ 60Hz VGA monitor, accepts player input from four physical switches, displays live scores on dual 7-segment displays, and uses a UART byte from a host PC as the start-round trigger. Game logic operates on a coarse **40x30 game grid** that is upscaled to the full VGA resolution at render time. Includes paddle-section bounce angles, an LFSR-randomized serve direction, and a progressive ball speed-up that scales with rally length.

**Note:** This project was a deep dive into VGA timing, frame-synchronous game logic, multi-FSM coordination, and pseudo-random hardware sequencing. It built on the foundation laid by my Morse Code project (FSM design and UART communication) and added real-time graphics output as a new dimension.

## Hardware Demonstration
https://github.com/user-attachments/assets/aaef65b2-a423-4d72-ae3b-dff3547200c1

This demonstration captures a continuous gameplay session that exercises every major feature of the design. The sequence highlights:
1. **Paddle controls:** Both paddles move up and down to confirm the four debounced switches are wired correctly and feeding the Paddle_Move FSMs.
2. **Paddle-section bounce angles:** Hits on the top, middle, and bottom thirds of a paddle reflect the ball at three distinct angles, demonstrating the variable-bounce logic.
3. **Speed-up curve:** A back-to-back straight-across rally accelerates the ball through its bounce-count-based speed tiers, with the ball noticeably faster after extended rallies.
4. **Scoring and round transition:** A deliberate miss demonstrates the score increment on the 7-segment display, the brief inter-round pause, and the FSM cycle from POINT_CHECK back to RUNNING.
5. **LFSR-randomized serve:** Multiple serves throughout the session show the four possible starting trajectories driven by the 16-bit Fibonacci LFSR, confirming the pseudo-random direction selection.
6. **Match win:** The session ends with one side reaching 5 points, triggering the WINNER state, score reset, and return to IDLE.

## Background & Motivation
After my Morse Code Decoder taught me FSM design and serial communication, I wanted a project that pushed me into real-time graphics. VGA was the natural target. The protocol is documented, the timing is straightforward at 25MHz (which is exactly the Go Board's clock), and rendering a single-pixel ball plus two paddles is a perfect scope for a follow-up project.

The added value of Pong over a static test pattern is that it forces you to coordinate multiple independent FSMs (paddle movement, ball physics, round/score tracking, video output), respect the frame boundary so updates do not tear, and produce pseudorandom behavior in pure hardware (the LFSR-driven serve direction).

## How It Works (System Architecture)
The design is split into a video-timing pipeline, gameplay logic, and a top-level wrapper that ties them to physical I/O.

### 1. Game Grid & Pixel Upscaling
Rather than tracking ball and paddle positions in raw VGA pixels, the game logic operates on a coarse **40x30 grid** of "game cells." Each cell is 16x16 actual VGA pixels, so the visible 640x480 frame divides cleanly into `(640 / 16) x (480 / 16) = 40 x 30` cells. This has three big advantages:
* **Reduced register width:** 10-bit ball/paddle positions can be replaced with much smaller game-grid coordinates, simplifying physics math.
* **Easier collision logic:** Wall and paddle hits become integer comparisons on whole cells rather than pixel-by-pixel tests.
* **Cleaner gameplay:** A "1 unit per frame" ball motion at 60Hz feels right when each unit is a 16-pixel jump rather than a single pixel.

The drawing logic in `Pong_Game.v` then upscales each game cell back to its 16x16 pixel block by shifting the cell coordinate left by `$clog2(c_GAME_SCALE) = 4`. The upscaling factor is parameterized, so changing `c_GAME_SCALE` immediately re-tunes the visual size of every object.

### 2. Video Timing Pipeline
* **VGA_Sync_Pulses:** Generates the 800x525 row/column counters at the 25MHz pixel clock and produces "active region" sync signals that are high while the beam is inside the visible 640x480 area.
* **VGA_Sync_Porch:** Adds the standard front porch and sync pulse timing required by VGA monitors, gates RGB to black during blanking, and produces the final HSync, VSync, and 9-bit RGB signals (3 bits per channel).

### 3. Gameplay Logic
* **Pong_Game (Main FSM):** Tracks rounds and scores through six states (IDLE, RUNNING, POINT_CHECK, NEXT_ROUND, SERVE, WINNER, CLEANUP). Watches the ball position to detect a miss, increments the appropriate score, then either returns to play or declares a winner at 5 points.
* **Paddle_Move:** Two identical instances, one per player. Moves the paddle one game-grid cell per frame tick when the corresponding switch is held, clamped to the play area.
* **Ball_Move:** Handles ball position, wall bounces, and paddle collisions. Splits each paddle into thirds for variable bounce angles (top third reflects upward, middle reflects straight, bottom reflects downward). Uses a 16-bit Fibonacci LFSR with taps at 16/14/13/11 to randomize serve direction at the start of each round. Bounce count drives a difficulty curve that progressively shortens the per-step delay.

### 4. Frame Synchronization
* All gameplay updates are gated by a one-cycle "frame tick" pulse generated on the rising edge of VSync. This guarantees that paddle and ball positions only change during the vertical blanking interval, so no object can move mid-render and tear.

### 5. Score Display & Input
* **Binary_to_7Seg:** Combinational LUT that maps a 4-bit score (0-F) to seven segment patterns. One instance drives each player's display.
* **Debounce:** Filters mechanical switch bounce by requiring the input to remain stable for 10 ms before accepting a new state.
* **UART_RX (Nandland):** Receives any byte from the PC at 115200 baud. The data byte itself is unused; only the data-valid pulse is needed to start a round.

## Tools & Hardware
* **Language:** Verilog
* **Target:** Lattice iCE40 (Nandland Go Board)
* **Display:** VGA monitor at 640x480 @ 60Hz
* **Synthesis:** Yosys, NextPNR, and IceStorm (Open-source CLI flow)
* **Baud Rate:** 115200 (217 clocks per bit @ 25MHz)

## Lessons Learned
This project taught me how to structure a multi-FSM design where each block runs independently but stays coordinated through shared timing signals. The frame tick was the critical unlock: once I had a clean once-per-frame pulse, every gameplay subsystem could update at the right rate without polling or busy-waiting.

I also learned how **VGA timing pipelines** work in practice. Splitting the active-region generator from the front-porch generator made the design easier to reason about, but it taught me that careless duplication of counter logic is a real cost worth refactoring out. Implementing the LFSR for serve randomization was my first practical use of pseudo-random hardware sequences and made the gameplay feel genuinely unpredictable. Most importantly, the project proved that the same FSM and debouncing patterns from my earlier Morse project scale up cleanly to a much larger system.
