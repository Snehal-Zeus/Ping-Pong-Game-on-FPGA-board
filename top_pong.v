// top_pong.v -- top level wiring for VGA Pong with lives
module top_pong(
    input  wire CLOCK_50,      // 50 MHz board clock
    input  wire [3:0] KEY,     // KEY[0]=reset (active-low), KEY[1]=left up, KEY[2]=left down
    input  wire [9:0] SW,      // switches (not used for AI-only)
    // VGA outputs
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire VGA_CLK,
    output wire VGA_BLANK_N,
    output wire VGA_HS,
    output wire VGA_VS,
    output wire VGA_SYNC_N,
	 output [6:0] HEX0,
	 output [6:0] HEX1

);

    // reset and controls
    wire rst_n = KEY[0];    // active low reset
    wire key1_n = KEY[1];
    wire key2_n = KEY[2];

    // 50 -> 25 MHz pixel clock (simple /2 flip)
    wire pclk;
    clk_div u_clk_div(.clk_in(CLOCK_50), .rst_n(rst_n), .clk_out(pclk));

    // generate 60Hz tick (one-cycle pulse per update)
    wire tick_60;
    game_tick_60hz tickgen (.clk_25mhz(pclk), .rst_n(rst_n), .tick(tick_60));

    // VGA timing generator
    wire hsync, vsync, visible;
    wire [9:0] px, py;
    vga_timing_640x480 u_vga(.pclk(pclk), .rst_n(rst_n),
                             .hsync(hsync), .vsync(vsync),
                             .visible(visible), .px(px), .py(py));

    // game logic (AI-right, left keyboard)
    wire [9:0] ball_x, ball_y, paddleL_y, paddleR_y;
    wire [2:0] lives_player, lives_ai; // 3-bit lives each
	 wire [7:0] ball_speed;


    pong_logic u_game(
        .clk(tick_60),
        .rst_n(rst_n),
        .key1_n(key1_n),
        .key2_n(key2_n),
        .h_res(10'd640),
        .v_res(10'd480),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddleL_y(paddleL_y),
        .paddleR_y(paddleR_y),
        .lives_player(lives_player),
        .lives_ai(lives_ai),
		  .ball_speed(ball_speed) 
    );
	 
	 

    // pixel generator draws ball, paddles, and lives
    wire [7:0] red, green, blue;
    pixel_gen u_pix(
        .visible(visible),
        .px(px),
        .py(py),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddleL_y(paddleL_y),
        .paddleR_y(paddleR_y),
        .lives_player(lives_player),
        .lives_ai(lives_ai),
        .red(red),
        .green(green),
        .blue(blue)
    );
	 
	 // 7-segemnt display for speed	 
	 seg7_driver u_seg(
    .value(ball_speed),
    .HEX0(HEX0),
    .HEX1(HEX1)
	 );


    // drive VGA outputs
    assign VGA_R = red;
    assign VGA_G = green;
    assign VGA_B = blue;
    assign VGA_HS = hsync;
    assign VGA_VS = vsync;
    assign VGA_CLK = pclk;
    assign VGA_BLANK_N = visible;
    assign VGA_SYNC_N = 1'b1;

endmodule
