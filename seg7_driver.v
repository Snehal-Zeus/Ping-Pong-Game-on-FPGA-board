// seg7_driver.v
// Converts decimal value (0–99) into HEX0 & HEX1 7-segment signals.
// Common-anode: 0 = ON, 1 = OFF.

module seg7_driver(
    input  wire [7:0] value,   // ball speed (0–99)
    output reg  [6:0] HEX0,    // ones digit
    output reg  [6:0] HEX1     // tens digit
);

    reg [3:0] ones;
    reg [3:0] tens;

    // Extract digits
    always @(*) begin
        ones = value % 10;
        tens = value / 10;
    end

    // Digit → 7-segment encoding (active-low)
    function [6:0] seg7;
        input [3:0] d;
        case (d)
            4'd0: seg7 = 7'b100_0000;
            4'd1: seg7 = 7'b111_1001;
            4'd2: seg7 = 7'b010_0100;
            4'd3: seg7 = 7'b011_0000;
            4'd4: seg7 = 7'b001_1001;
            4'd5: seg7 = 7'b001_0010;
            4'd6: seg7 = 7'b000_0010;
            4'd7: seg7 = 7'b111_1000;
            4'd8: seg7 = 7'b000_0000;
            4'd9: seg7 = 7'b001_0000;
            default: seg7 = 7'b111_1111;
        endcase
    endfunction

    always @(*) begin
        HEX0 = seg7(ones);
        HEX1 = seg7(tens);
    end
endmodule
