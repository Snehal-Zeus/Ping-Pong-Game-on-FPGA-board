// vga_timing_640x480.v
// Generate hsync, vsync, visible area, pixel X/Y for 640x480@60Hz (25 MHz pixel clock)

module vga_timing_640x480(
    input  wire pclk,       // 25 MHz
    input  wire rst_n,
    output reg  hsync,
    output reg  vsync,
    output reg  visible,
    output reg [9:0] px,    // pixel x: 0..(total_width-1)
    output reg [9:0] py     // pixel y: 0..(total_height-1)
);

// Based on table from DE10 manual (640x480@60Hz)
localparam H_VISIBLE = 640;
localparam H_FRONT   = 16;   // front porch
localparam H_SYNC    = 96;   // sync pulse
localparam H_BACK    = 48;   // back porch
localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

localparam V_VISIBLE = 480;
localparam V_FRONT   = 10;
localparam V_SYNC    = 2;
localparam V_BACK    = 33;
localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        px <= 0; py <= 0;
        hsync <= 1'b1;
        vsync <= 1'b1;
        visible <= 1'b0;
    end else begin
        // advance pixel
        if (px == H_TOTAL - 1) begin
            px <= 0;
            if (py == V_TOTAL - 1) py <= 0;
            else py <= py + 1;
        end else begin
            px <= px + 1;
        end

        // hsync: active low during sync window (after visible + front)
        if ( (px >= H_VISIBLE + H_FRONT) && (px < H_VISIBLE + H_FRONT + H_SYNC) )
            hsync <= 1'b0;
        else
            hsync <= 1'b1;

        // vsync
        if ( (py >= V_VISIBLE + V_FRONT) && (py < V_VISIBLE + V_FRONT + V_SYNC) )
            vsync <= 1'b0;
        else
            vsync <= 1'b1;

        // visible when within visible region
        if ( (px < H_VISIBLE) && (py < V_VISIBLE) )
            visible <= 1'b1;
        else
            visible <= 1'b0;
    end
end

endmodule
