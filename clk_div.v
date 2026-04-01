// clk_div.v -- divide 50 MHz -> 25 MHz (simple toggle)
/*
  Input: clk_in (50MHz)
  Output: clk_out (25MHz)
*/
module clk_div(
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            clk_out <= 1'b0;
        else
            clk_out <= ~clk_out;
    end
endmodule
