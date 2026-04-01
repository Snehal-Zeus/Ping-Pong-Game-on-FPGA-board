// pixel_gen.v -- draws paddles, ball and lives (hearts) on VGA 640x480
module pixel_gen(
    input  wire visible,
    input  wire [9:0] px,
    input  wire [9:0] py,
    input  wire [9:0] ball_x,
    input  wire [9:0] ball_y,
    input  wire [9:0] paddleL_y,
    input  wire [9:0] paddleR_y,
    input  wire [2:0] lives_player,
    input  wire [2:0] lives_ai,
    output reg  [7:0] red,
    output reg  [7:0] green,
    output reg  [7:0] blue
);

    // constants
    localparam PADDLE_W = 8;
    localparam PADDLE_H = 48;
    localparam BALL_SIZE = 8;
    localparam H_RES = 640;
    // heart glyph: 8x8 bitmap (1=filled)
    // rows from top (row0) to bottom (row7)
    function [7:0] heart_row;
        input [2:0] r;
        begin
            case (r)
                3'd0: heart_row = 8'b01100110;
                3'd1: heart_row = 8'b11111111;
                3'd2: heart_row = 8'b11111111;
                3'd3: heart_row = 8'b11111111;
                3'd4: heart_row = 8'b01111110;
                3'd5: heart_row = 8'b00111100;
                3'd6: heart_row = 8'b00011000;
                3'd7: heart_row = 8'b00000000;
                default: heart_row = 8'b00000000;
            endcase
        end
    endfunction

    // heart parameters
    localparam HEART_W = 8;
    localparam HEART_H = 8;
    localparam HEART_MARGIN = 6;
    localparam PLAYER_HEART_X0 = 10;                 // left group start
    localparam PLAYER_HEART_Y0 = 8;                  // top offset
    localparam AI_HEART_X0 = H_RES - 10 - HEART_W;   // rightmost heart anchor x

    // compute object flags
    wire in_ball = (px >= ball_x) && (px < ball_x + BALL_SIZE) && (py >= ball_y) && (py < ball_y + BALL_SIZE);
    wire in_paddleL = (px >= 2) && (px < 2 + PADDLE_W) && (py >= paddleL_y) && (py < paddleL_y + PADDLE_H);
    wire in_paddleR = (px >= (H_RES - PADDLE_W - 10)) && (px < (H_RES - 10)) && (py >= paddleR_y) && (py < paddleR_y + PADDLE_H);

    // heart pixel check function
    function heart_pixel;
        input integer hx; // heart top-left x
        input integer hy; // heart top-left y
        input [9:0] x;
        input [9:0] y;
        reg [2:0] row;
        reg [2:0] col;
        reg [7:0] rbits;
        begin
            heart_pixel = 1'b0;
            // local coordinates
            if ((x >= hx) && (x < hx + HEART_W) && (y >= hy) && (y < hy + HEART_H)) begin
                row = y - hy;
                col = x - hx;
                rbits = heart_row(row);
                // highest bit corresponds to col=7; map col 0..7 -> bit [7-col]
                heart_pixel = rbits[7 - col];
            end
        end
    endfunction

    integer i;
    reg heart_active;

    always @(*) begin
        if (!visible) begin
            red = 8'h00; green = 8'h00; blue = 8'h00;
        end else begin
            // default background: black
            red = 8'h00; green = 8'h00; blue = 8'h00;

            // draw ball first (orange)
            if (in_ball) begin
                red = 8'hFF; green = 8'h66; blue = 8'h00;
            end
            // draw paddles (white)
            else if (in_paddleL || in_paddleR) begin
                red = 8'hFF; green = 8'hFF; blue = 8'hFF;
            end
            else begin
                // hearts (player left)
                heart_active = 1'b0;
                for (i = 0; i < lives_player; i = i + 1) begin
                    // each heart is PLAYER_HEART_X0 + i*(HEART_W + HEART_MARGIN)
                    if (heart_pixel(PLAYER_HEART_X0 + i*(HEART_W + HEART_MARGIN), PLAYER_HEART_Y0, px, py)) begin
                        heart_active = 1'b1;
                    end
                end

                // hearts (AI right) draw from right to left
                for (i = 0; i < lives_ai; i = i + 1) begin
                    integer hx;
                    hx = AI_HEART_X0 - i*(HEART_W + HEART_MARGIN);
                    if (heart_pixel(hx, PLAYER_HEART_Y0, px, py)) begin
                        heart_active = 1'b1;
                    end
                end

                if (heart_active) begin
                    // red heart color
                    red = 8'hFF; green = 8'h22; blue = 8'h22;
                end else begin
                    // background remains black (could draw midline, etc.)
                    red = 8'h00; green = 8'h00; blue = 8'h00;
                end
            end
        end
    end

endmodule
