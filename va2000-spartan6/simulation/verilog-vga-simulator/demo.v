// This is a simulation-only example of generating a VGA-like pixel clock video
// signal.

module vgasimdemo;
   reg pclk;
   reg [4:0] r;
   reg [4:0] g;
   reg [4:0] b;
   reg hsync;
   reg vsync;
   reg [19:0] x;
   reg [19:0] y;
   reg [4:0]  mask;

   localparam dots_per_line = 800 + 40 + 128 + 88;
   localparam lines_per_frame = 600 + 1 + 4 + 23;

   wire       in_screen = (x < 800 && y < 600);

   initial begin
      x = 0;
      y = 0;
      pclk = 0;
      hsync = 1;
      vsync = 1;
      mask = 0;

      $vgasimInit(
          dots_per_line,
          lines_per_frame,
          r, g, b,
          hsync, vsync,
          pclk
      );
   end

   always @(negedge pclk) begin
      r <= in_screen ? (~x) ^ mask : 0;
      g <= in_screen ? y ^ mask : 0;
      b <= in_screen ? 0 : 0;

      x <= (x == dots_per_line ? 0 : x + 1);

      if (x == dots_per_line)
        y <= (y == lines_per_frame ? 0 : y + 1);

      mask <= (y == lines_per_frame) ? mask + 1 : mask;

      hsync <= ~(x >= 840 && x < 968);
      vsync <= ~(y >= 601 && y < 615);
   end

   always #1 pclk = ~pclk;
endmodule
