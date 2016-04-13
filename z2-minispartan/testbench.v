`timescale 1ns/1ns

module testbench;
   reg z_sample_clk = 0;
   reg vgaclk = 0;
   reg e7m = 0;
   reg znAS = 1;
   reg znUDS = 1;
   reg znLDS = 1;
   reg zREAD = 1;
   reg zDOE = 0;
   reg znCFGIN = 0;
   
   reg [23:0] zA = 'he80000 - 2;
   reg data_out_ready = 0;
   reg cmd_ready = 0;

   reg rtoggle = 0;
   
   wire [15:0] zD;
   
   z2 z(.z_sample_clk(z_sample_clk),
        .vga_clk(vgaclk),
        .znAS(znAS),
        .zE7M(e7m),
        .znUDS(znUDS),
        .znLDS(znLDS),
        .zREAD(zREAD),
        .zA(zA),
        .zD(zD),
        .zDOE(zDOE),
        .znCFGIN(znCFGIN));
   
   reg [15:0] zDReg = 0;
   assign zD = zDOE?'hzzzz:zDReg;
   
   initial
     begin
        $dumpfile("test.vcd");
        $dumpvars(0,z);

        #500000 $finish;
        
     end // initial begin

   always
     begin
        #0 zREAD = 1;
        #130 zREAD = rtoggle;
        //rtoggle = !rtoggle;
        
        #12 znAS = 0;
        zA = zA + 2;
        zDReg = 'hbeef;

        if (zA>'he80100) begin
          znCFGIN = 1;
          zA = 'h600000;
        end
        
        #142 znUDS = 0;
        znLDS = 0;

        #200 znUDS = 1;
        znLDS = 1; 
        zDOE = 1;
        
        #80 zDOE = 0;
        
        #4 znAS = 1;
     end

   always
     #5 z_sample_clk = !z_sample_clk;

   always
     #6.65 vgaclk = !vgaclk;
   
   always
     begin
       #74 e7m = !e7m;
       if (zDOE && zREAD) begin
         $display("68k read: %h\t%h", zA, zD);
       end
     end
   
endmodule
