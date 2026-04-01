// pong_logic.v -- Pong logic with AI, lives, collisions and speed control
// Life checks use fixed-point comparisons to avoid signed/unsigned pitfalls.

module pong_logic(
    input  wire        clk,       // game tick (e.g., 60 Hz)
    input  wire        rst_n,     // active-low reset
    input  wire        key1_n,    // left up (active-low)
    input  wire        key2_n,    // left down (active-low)
    input  wire [9:0]  h_res,     // horizontal resolution (e.g., 640)
    input  wire [9:0]  v_res,     // vertical resolution (e.g., 480)

    output reg [9:0] ball_x,
    output reg [9:0] ball_y,
    output reg [9:0] paddleL_y,
    output reg [9:0] paddleR_y,
    output reg [2:0] lives_player,
    output reg [2:0] lives_ai,
	 output reg [7:0] ball_speed   // speed for 7-seg display

);

    // ---------------- PARAMETERS ----------------
    localparam integer PADDLE_W  = 8;
    localparam integer PADDLE_H  = 48;
    localparam integer BALL_SIZE = 8;

    // fixed-point Q12.4
    localparam integer FP_SHIFT = 4;
    localparam integer FP_ONE   = (1 << FP_SHIFT);

    // speeds (Q4)
    localparam integer BALL_SPEED_X_INIT = 3 * FP_ONE;
    localparam integer BALL_SPEED_Y_INIT = 0 * FP_ONE;
    localparam integer BALL_SPEED_DELTA  = (FP_ONE/2);    // +0.5 px/tick (Q4)
    localparam integer MAX_BALL_SPEED    = 12 * FP_ONE;

    localparam integer PADDLE_SPEED = 4;
    localparam integer PADDLE_ANGLE_FACTOR = 2 * FP_ONE;

    localparam integer AI_SPEED = 2;
    localparam integer AI_DEADZONE = 3;

    // ---------- STATE ----------
    reg signed [15:0] ball_x_fp;
    reg signed [15:0] ball_y_fp;
    reg signed [15:0] ball_vx;   // Q4
    reg signed [15:0] ball_vy;   // Q4

    // predicted next
    reg signed [15:0] next_x_fp;
    reg signed [15:0] next_y_fp;

    // temps
    integer next_x_int;
    integer bx0, bx1, by0, by1;
    integer pL_x0, pL_x1, pL_y0, pL_y1;
    integer pR_x0, pR_x1, pR_y0, pR_y1;
    integer paddle_center;
    integer hit_offset;
    reg signed [31:0] mag_vx;
    reg signed [31:0] tmp_vy;
    integer ball_center_int;
    integer init_cx, init_cy;
	 integer abs_vx, abs_vy;

    // fixed-point thresholds for misses (precompute in code)
    wire signed [31:0] left_miss_fp  = - (BALL_SIZE <<< FP_SHIFT);               // -BALL_SIZE in Q4
    wire signed [31:0] right_miss_fp = ((h_res + BALL_SIZE) <<< FP_SHIFT);     // (h_res + BALL_SIZE) in Q4

    // -------- initialization ----------
    initial begin
        lives_player = 5;
        lives_ai     = 5;
    end

    // ---------- MAIN ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_cx = h_res >>> 1;
            init_cy = v_res >>> 1;

            ball_x_fp <= init_cx << FP_SHIFT;
            ball_y_fp <= init_cy << FP_SHIFT;
            ball_vx   <= BALL_SPEED_X_INIT;
            ball_vy   <= BALL_SPEED_Y_INIT;

            paddleL_y <= (v_res - PADDLE_H) >>> 1;
            paddleR_y <= (v_res - PADDLE_H) >>> 1;

            lives_player <= 5;
            lives_ai     <= 5;

            ball_x <= init_cx;
            ball_y <= init_cy;
        end else begin
            // If game over, freeze (no updates) - preserves lives on display
            if (lives_player == 0 || lives_ai == 0) begin
                // keep outputs stable; do not update physics or paddles
                ball_x <= ball_x_fp >>> FP_SHIFT;
                ball_y <= ball_y_fp >>> FP_SHIFT;
            end else begin
                // ---------- Player input ----------
                if (!key1_n && paddleL_y > 0)
                    paddleL_y <= paddleL_y - PADDLE_SPEED;
                else if (!key2_n && paddleL_y < v_res - PADDLE_H)
                    paddleL_y <= paddleL_y + PADDLE_SPEED;

                // clamp
                if (paddleL_y < 0) paddleL_y <= 0;
                if (paddleL_y > v_res - PADDLE_H) paddleL_y <= v_res - PADDLE_H;

                // ---------- AI movement ----------
                ball_center_int = (ball_y_fp >>> FP_SHIFT) + (BALL_SIZE >>> 1);
                if (paddleR_y + (PADDLE_H >>> 1) + AI_DEADZONE < ball_center_int && paddleR_y < v_res - PADDLE_H)
                    paddleR_y <= paddleR_y + AI_SPEED;
                else if (paddleR_y + (PADDLE_H >>> 1) - AI_DEADZONE > ball_center_int && paddleR_y > 0)
                    paddleR_y <= paddleR_y - AI_SPEED;

                // clamp AI
                if (paddleR_y < 0) paddleR_y <= 0;
                if (paddleR_y > v_res - PADDLE_H) paddleR_y <= v_res - PADDLE_H;

                // ---------- Predict next position ----------
                next_x_fp = ball_x_fp + ball_vx;
                next_y_fp = ball_y_fp + ball_vy;

                // integer extents for collision tests
                next_x_int = next_x_fp >>> FP_SHIFT;
                bx0 = next_x_int;
                bx1 = bx0 + BALL_SIZE - 1;
                by0 = next_y_fp >>> FP_SHIFT;
                by1 = by0 + BALL_SIZE - 1;

                // paddle boxes (left is fixed x=8; right computed from h_res)
                pL_x0 = 8;
                pL_x1 = 8 + PADDLE_W - 1;
                pL_y0 = paddleL_y;
                pL_y1 = paddleL_y + PADDLE_H - 1;

                pR_x0 = h_res - PADDLE_W - 8;
                pR_x1 = pR_x0 + PADDLE_W - 1;
                pR_y0 = paddleR_y;
                pR_y1 = paddleR_y + PADDLE_H - 1;

                // ---------- Vertical wall bounce ----------
                if (next_y_fp <= 0) begin
                    next_y_fp = 0;
                    ball_vy <= -ball_vy;
                end else if (next_y_fp + (BALL_SIZE << FP_SHIFT) >= (v_res << FP_SHIFT)) begin
                    next_y_fp = (v_res << FP_SHIFT) - (BALL_SIZE << FP_SHIFT);
                    ball_vy <= -ball_vy;
                end

                // ---------- Collisions (paddles) ----------
                if (!(bx1 < pL_x0 || bx0 > pL_x1 || by1 < pL_y0 || by0 > pL_y1)) begin
                    // LEFT paddle collision
                    next_x_fp = (pL_x1 + 1) << FP_SHIFT;

                    // compute magnitude and increase (safe)
                    mag_vx = ball_vx;
                    if (mag_vx < 0) mag_vx = -mag_vx;
                    mag_vx = mag_vx + BALL_SPEED_DELTA;
                    if (mag_vx > MAX_BALL_SPEED) mag_vx = MAX_BALL_SPEED;
                    // set vx to positive magnitude (to right)
                    ball_vx <= mag_vx[15:0];

                    // vertical velocity from hit offset
                    paddle_center = pL_y0 + (PADDLE_H >>> 1);
                    hit_offset = (by0 + (BALL_SIZE >>> 1)) - paddle_center;
                    tmp_vy = (hit_offset * PADDLE_ANGLE_FACTOR) >>> FP_SHIFT;
                    if (tmp_vy > MAX_BALL_SPEED) tmp_vy = MAX_BALL_SPEED;
                    if (tmp_vy < -MAX_BALL_SPEED) tmp_vy = -MAX_BALL_SPEED;
                    ball_vy <= tmp_vy[15:0];

                    // commit positions
                    ball_x_fp <= next_x_fp;
                    ball_y_fp <= next_y_fp;
                end
                else if (!(bx1 < pR_x0 || bx0 > pR_x1 || by1 < pR_y0 || by0 > pR_y1)) begin
                    // RIGHT paddle collision
                    next_x_fp = (pR_x0 - BALL_SIZE) << FP_SHIFT;

                    // compute magnitude, increase and apply negative sign (to left)
                    mag_vx = ball_vx;
                    if (mag_vx < 0) mag_vx = -mag_vx;
                    mag_vx = mag_vx + BALL_SPEED_DELTA;
                    if (mag_vx > MAX_BALL_SPEED) mag_vx = MAX_BALL_SPEED;
                    ball_vx <= -mag_vx[15:0]; // negative to go left

                    // vertical velocity from hit offset
                    paddle_center = pR_y0 + (PADDLE_H >>> 1);
                    hit_offset = (by0 + (BALL_SIZE >>> 1)) - paddle_center;
                    tmp_vy = (hit_offset * PADDLE_ANGLE_FACTOR) >>> FP_SHIFT;
                    if (tmp_vy > MAX_BALL_SPEED) tmp_vy = MAX_BALL_SPEED;
                    if (tmp_vy < -MAX_BALL_SPEED) tmp_vy = -MAX_BALL_SPEED;
                    ball_vy <= tmp_vy[15:0];

                    // commit positions
                    ball_x_fp <= next_x_fp;
                    ball_y_fp <= next_y_fp;
                end
                else begin
                    // no paddle collision: accept predicted move
                    ball_x_fp <= next_x_fp;
                    ball_y_fp <= next_y_fp;
                end

                // ---------- Life loss detection (USE fixed-point thresholds) ----------
                // Compare ball_x_fp (Q4) directly to fixed-point thresholds to avoid sign/shift issues.

                // ball fully left of screen -> player missed
                if (ball_x_fp <= left_miss_fp) begin
                    if (lives_player > 0) lives_player <= lives_player - 1;
                    // reset ball to center and send toward the scorer (to right)
                    ball_x_fp <= (h_res >>> 1) << FP_SHIFT;
                    ball_y_fp <= (v_res >>> 1) << FP_SHIFT;
                    ball_vx   <= BALL_SPEED_X_INIT;
                    ball_vy   <= BALL_SPEED_Y_INIT;
                end
                // ball fully right of screen -> AI missed
                else if (ball_x_fp >= right_miss_fp) begin
                    if (lives_ai > 0) lives_ai <= lives_ai - 1;
                    ball_x_fp <= (h_res >>> 1) << FP_SHIFT;
                    ball_y_fp <= (v_res >>> 1) << FP_SHIFT;
                    ball_vx   <= -BALL_SPEED_X_INIT;
                    ball_vy   <= BALL_SPEED_Y_INIT;
                end

                // defensive clamps
                if (ball_vx == 0) ball_vx <= BALL_SPEED_X_INIT;
                if (ball_vy > MAX_BALL_SPEED) ball_vy <= MAX_BALL_SPEED;
                if (ball_vy < -MAX_BALL_SPEED) ball_vy <= -MAX_BALL_SPEED;
					 
					 // Compute speed magnitude in pixels per tick
					 // speed = sqrt(vx² + vy²) but we approximate with |vx| + |vy|
					 abs_vx = (ball_vx < 0) ? -ball_vx : ball_vx;
					 abs_vy = (ball_vy < 0) ? -ball_vy : ball_vy;

					 // Convert from Q4 fixed point → integer pixels (divide by 16)
					 ball_speed <= (abs_vx + abs_vy) >>> FP_SHIFT;

					 // clamp to 0–99 for display
					 if (ball_speed > 99) ball_speed <= 99;


                // update integer outputs for pixel generator
                ball_x <= ball_x_fp >>> FP_SHIFT;
                ball_y <= ball_y_fp >>> FP_SHIFT;
            end // not game over
        end // else rst_n
    end // always

endmodule
