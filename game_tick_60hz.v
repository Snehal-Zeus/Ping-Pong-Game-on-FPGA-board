// game_tick_60hz.v
// Generate a single-cycle tick at ~60 Hz from 25 MHz pixel clock.
//
// Usage: connect pclk (25 MHz) and rst_n (active-low reset).
// Output 'tick' is high for one pclk cycle every ~1/60 s.

module game_tick_60hz (
    input  wire clk_25mhz,
    input  wire rst_n,
    output reg  tick
);

    // 25,000,000 / 60 = 416,666.666... -> use 416,666
    localparam integer COUNT_MAX = 416666;

    // counter bits: need enough bits to hold COUNT_MAX
    reg [18:0] counter; // 19 bits (max 524287)

    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 19'd0;
            tick <= 1'b0;
        end else begin
            if (counter >= COUNT_MAX) begin
                counter <= 19'd0;
                tick <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
                tick <= 1'b0;
            end
        end
    end
endmodule
