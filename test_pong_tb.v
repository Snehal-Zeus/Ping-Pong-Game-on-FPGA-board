`timescale 1ns/1ps
module test_pong_tb;

    reg clk;
    reg rst_n;
    reg key1_n;    // up
    reg key2_n;    // down
    wire [9:0] ball_x, ball_y;
    wire [9:0] paddleL_y, paddleR_y;
    wire [2:0] lives_player, lives_ai;
    wire [7:0] ball_speed;

    test_pong uut (
        .clk(clk),
        .rst_n(rst_n),
        .key1_n(key1_n),
        .key2_n(key2_n),
        .h_res(640),
        .v_res(480),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddleL_y(paddleL_y),
        .paddleR_y(paddleR_y),
        .lives_player(lives_player),
        .lives_ai(lives_ai),
        .ball_speed(ball_speed)
    );

    always #800 clk = ~clk; 
    // Fake 60 Hz tick -> period 16.666 ms → ~8,000,000 ns
    // I scale it down by 1000× so simulation runs fast: #8000 = 8 microseconds.

    initial begin
        clk = 0;
        rst_n = 0;
        key1_n = 1;
        key2_n = 1;

        #1000;
        rst_n = 1;

	 forever begin
			// Move paddle up
			key1_n = 0;
			#5000;  // Time the paddle stays up
			key1_n = 1;

			// Move paddle down
			key2_n = 0;
			#5000;  // Time the paddle stays down
			key2_n = 1;
        end

        #5000000;
        $finish;
    end

endmodule
