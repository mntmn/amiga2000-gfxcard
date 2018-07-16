`timescale 1ns/1ns

module testbench;
  reg z_sample_clk = 0;
  reg vgaclk = 0;
  reg e7m = 0;
  reg znAS = 1;
  reg znFCS = 1;
  reg znUDS = 1;
  reg znLDS = 1;
  reg znDS1 = 1;
  reg znDS0 = 1;
  reg zREAD = 1;
  reg zDOE = 0;
  reg znCFGIN = 0;
  
  reg data_out_ready = 0;
  reg cmd_ready = 0;

  reg rtoggle = 0;
  
  wire [15:0] zD;
  wire [22:0] zA;
  wire [7:0] vga_r;
  wire [7:0] vga_g;
  wire [7:0] vga_b;
  wire vga_hs;
  wire vga_vs;

  wire [4:0] vga_low_r;
  wire [4:0] vga_low_g;
  wire [4:0] vga_low_b;

  wire SDRAM_CLK;
  wire SDRAM_CKE;
  wire SDRAM_nCS;
  wire SDRAM_nRAS;
  wire SDRAM_nCAS;
  wire SDRAM_nWE;
  wire [1:0]  SDRAM_DQM;
  wire [12:0] SDRAM_A;
  wire [1:0]  SDRAM_BA;
  wire [15:0] SDRAM_D;
  
  mt48lc16m16a2 sdram(.Dq(SDRAM_D), 
                      .Addr(SDRAM_A), 
                      .Ba(SDRAM_BA),
                      .Clk(SDRAM_CLK), 
                      .Cke(SDRAM_CKE), 
                      .Cs_n(SDRAM_nCS), 
                      .Ras_n(SDRAM_nRAS), 
                      .Cas_n(SDRAM_nCAS), 
                      .We_n(SDRAM_nWE), 
                      .Dqm(SDRAM_DQM));
  
  va2000 z(.z_sample_clk(z_sample_clk),
           .vga_clk(vgaclk),
           .znAS(znAS),
           .znFCS(znFCS),
           .zE7M(e7m),
           .znUDS(znUDS),
           .znLDS(znLDS),
           .znDS1(znDS1),
           .znDS0(znDS0),
           .zREAD(zREAD),
           .zA(zA),
           .zD(zD),
           .zDOE(zDOE),
           .znCFGIN(znCFGIN),
           .vga_hs(vga_hs),
           .vga_vs(vga_vs),
           .vga_r(vga_r),
           .vga_g(vga_g),
           .vga_b(vga_b),

           .D(SDRAM_D),
           .A(SDRAM_A), 
           .SDRAM_BA(SDRAM_BA),
           .SDRAM_CLK(SDRAM_CLK), 
           .SDRAM_CKE(SDRAM_CKE), 
           .SDRAM_nCS(SDRAM_nCS), 
           .SDRAM_nRAS(SDRAM_nRAS), 
           .SDRAM_nCAS(SDRAM_nCAS), 
           .SDRAM_nWE(SDRAM_nWE), 
           .SDRAM_DQM(SDRAM_DQM)
           );
  
  reg [23:0] zAReg = 'h000000;
  reg [15:0] zDReg = 'hff00;
  assign zD = zDOE?'hzzzz:zDReg;
  assign zA = zAReg[23:1];

  reg [7:0] testbench_state = 0;
  
  localparam dots_per_line = 800 + 40 + 128 + 88;
  localparam lines_per_frame = 600 + 1 + 4 + 23;

  assign vga_low_r = vga_r[7:3];
  assign vga_low_g = vga_g[7:3];
  assign vga_low_b = vga_b[7:3];
  
  initial
    begin
      $dumpfile("test.vcd");
      $dumpvars(0,z);

      $vgasimInit(
          dots_per_line,
          lines_per_frame,
          vga_low_r, vga_low_g, vga_low_b,
          vga_hs, vga_vs,
          vgaclk
      );

      #20000000 $finish;
    end

  always
    begin
      #0

      if (testbench_state == 0) begin
        // read Z2 autoconf registers
        if (zAReg>'h000020) begin
          testbench_state = 1;
        end else
          zAReg = zAReg + 2;
      end
      else if (testbench_state == 1) begin
        // write Z2 autoconf register to finish config
        // TODO set memory address
        zREAD = 0;
        zDReg = 'hff00;
        zAReg = 'h00004c;
        testbench_state = 3;
      end
      else if (testbench_state == 3) begin
        testbench_state = 250;
      end

      // zorro3 read/write test -----------------------
      /*else if (testbench_state == 6) begin
        zREAD = 0;
        zDReg = 'h48ff;
        zAReg = 'h010000;
        testbench_state = 6;
      end
      else if (testbench_state == 7) begin
        zREAD = 1;
        zDReg = 'h4800;
        zAReg = 'h010004;
        testbench_state = 8;
      end*/
      
      if (testbench_state < 250) begin
        #12 znFCS = 0;
        #142 znUDS = 0;
        znLDS = 0;
        znDS1 = 0;
        znDS0 = 0;
        #200 znUDS = 1;
        znLDS = 1; 
        znDS1 = 1;
        znDS0 = 1;
        zDOE = 1;
        #80 zDOE = 0;
        #4 znFCS = 1;
        #4 zREAD = 1;
      end else
        #200 zREAD = 1;

      //$display("testbench_state: %h %t",testbench_state,$time);
    end

  always
    #5 z_sample_clk = !z_sample_clk;

  always
    #13.3 vgaclk = !vgaclk;
  
  always
    begin
      #74 e7m = !e7m;
      //if (!zDOE && zREAD) begin
      //  $display("68k read: %h\t%h", zAReg, zD);
      //end
      if (!zDOE && !zREAD) begin
        $display("68k write: %h\t%h", zAReg, zDReg);
      end
    end
  
endmodule
