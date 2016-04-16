`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MNT Media & Technology UG
// Engineer: Lukas F. Hartmann
// 
// Create Date:    01:44:12 05/03/2015 
// Design Name: 
// Module Name:    vga 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module vga(
  output vsync,
  output hsync,
  output reg vgaclock,
  output reg[15:0] rgb,
  output reg LED1,
  input CLK_IN1,
	 
  output SDRAM_CLK,  
  output SDRAM_CKE,  
  output SDRAM_CS,   
  output SDRAM_nRAS,  
  output SDRAM_nCAS,
  output SDRAM_nWE,   
  output [1:0]  SDRAM_DQM,  
  output [12:0] SDRAM_ADDR, 
  output [1:0]  SDRAM_BA,
  inout  [15:0] SDRAM_DATA,
  
  inout  [15:0] z_host,
  output reg sel_data,
  output reg sel_addr,
  input bcfgin,
  input bas,
  input e7m,
  input buds,
  output bcfgout,
  input doe,
  output bslaven,
  input read,
  
  output aux1,
  output aux2,
  output aux3
);

assign aux1 = 1;
assign aux2 = 1;
assign aux3 = 1;

wire sdram_reset;
reg ram_enable;
reg [18:0] ram_addr;
wire [31:0] ram_data_out;
wire data_out_ready;
reg [31:0] ram_data_in;
reg ram_write;
reg [3:0] ram_byte_enable;

DCM instance_name(
  .CLK_IN1(CLK_IN1),
  .CLK_OUT1(clk), // 100 
  .CLK_OUT2(ram_clk_gen), // 50
  .CLK_OUT3(vga_clk_gen),
  .CLK_OUT4(z_sample_clk));
	 
SDRAM_Controller_v sdram(
  .clk(sdram_clk),   
  .reset(sdram_reset),
  // command and write port
  .cmd_ready(cmd_ready), 
  .cmd_enable(ram_enable), 
  .cmd_wr(ram_write), 
  .cmd_byte_enable(ram_byte_enable), 
  .cmd_address(ram_addr), 
  .cmd_data_in(ram_data_in),
  // Read data port
  .data_out(ram_data_out),
  .data_out_ready(data_out_ready),

  // signals
  .SDRAM_CLK(SDRAM_CLK),  
  .SDRAM_CKE(SDRAM_CKE),  
  .SDRAM_CS(SDRAM_CS), 
  .SDRAM_RAS(SDRAM_RAS),
  .SDRAM_CAS(SDRAM_CAS),
  .SDRAM_WE(SDRAM_WE),   
  .SDRAM_DATA(SDRAM_DATA),
  .SDRAM_ADDR(SDRAM_ADDR),
  .SDRAM_DQM(SDRAM_DQM),
  .SDRAM_BA(SDRAM_BA) 
	);
/*
reg [7:0] ROM [255:0];
initial
begin
ROM[0]=128;
ROM[255]=125;
end*/

assign sdram_reset = 0;

assign SDRAM_nRAS = SDRAM_RAS;
assign SDRAM_nCAS = SDRAM_CAS;
assign SDRAM_nWE  = SDRAM_WE;

reg [9:0] counter_x;
reg [8:0] counter_y;
reg [11:0] counter_frame;
wire counter_xmaxed = (counter_x==767);
reg vga_HS, vga_VS;

reg [31:0] ram_data_buffer [639:0];
reg written;

reg [7:0] host_addr_buf;
reg host_pixel_buf;

assign sdram_clk = ram_clk_gen;

// 64k space from
// 00e80000 - 00e8ffff
// http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02C8.htm

localparam Z_UNCONFIGURED=0;
localparam Z_CONF_ROM=1;
localparam Z_CONF_RAM=2;
localparam Z_CONF_DONE=3;

localparam TC_A1=1;
localparam TC_SWITCH=2;
localparam TC_A2=3;


reg [3:0]  z_state;
reg [23:0] z_base_addr;
reg [23:0] z_addr;
reg [15:0] z_data;

reg [23:0] z_addr_buffer;

reg [10:0] cycle=0;
reg [13:0] rt_cycle=0;
reg [7:0] z_cycle=0;

// doe_latched is vitally important
wire [15:0] z_host_wire;
assign z_host_write = (z_addrmatch);
assign z_host =  (z_host_write) ?  z_host_wire : 'bzzzz_zzzz_zzzz_zzzz;
assign bslaven = !(z_addrmatch);
reg z_addrmatch=0;

assign z_host_wire[0] = z_data[15];
assign z_host_wire[1] = z_data[14];
assign z_host_wire[2] = z_data[13];
assign z_host_wire[3] = z_data[12];
assign z_host_wire[4] = z_data[11];
assign z_host_wire[5] = z_data[10];
assign z_host_wire[6] = z_data[9];
assign z_host_wire[7] = z_data[8];
assign z_host_wire[8] = z_data[7];
assign z_host_wire[9] = z_data[6];
assign z_host_wire[10] = z_data[5];
assign z_host_wire[11] = z_data[4];
assign z_host_wire[12] = z_data[3];
assign z_host_wire[13] = z_data[2];
assign z_host_wire[14] = z_data[1];
assign z_host_wire[15] = z_data[0];

assign bcfgout = !(z_state == Z_CONF_DONE);

reg [3:0] errors=0;
reg [4:0] z_debounce=0;

reg rec_e7m [0:639];
reg rec_bas [0:639];
reg rec_read [0:639];
reg rec_buds [0:639];
reg rec_doe [0:639];

reg rec_bslaven [0:639];
reg rec_z_host_write [0:639];
reg rec_doe_latched [0:639];

reg rec_addr1 [0:639];
reg rec_addr2 [0:639];
reg rec_addr3 [0:639];
reg rec_addr4 [0:639];
reg rec_addr5 [0:639];
reg rec_addr6 [0:639];
reg rec_addr7 [0:639];
reg rec_addr8 [0:639];
reg rec_addr9 [0:639];
reg rec_addr10 [0:639];
reg rec_addr11 [0:639];
reg rec_addr12 [0:639];
reg rec_addr13 [0:639];
reg rec_addr14 [0:639];
reg rec_addr15 [0:639];
reg rec_addr16 [0:639];
reg rec_addr17 [0:639];
reg rec_addr18 [0:639];
reg rec_addr19 [0:639];
reg rec_addr20 [0:639];
reg rec_addr21 [0:639];
reg rec_addr22 [0:639];
reg rec_addr23 [0:639];

reg rec_zcycle [0:639];

reg rec_addrmatch [0:639];

reg doe_latched=0;

reg [3:0] doe_time=0;
reg [3:0] notdoe_time=0;

always @(posedge z_sample_clk) begin
  sel_data <= !z_addrmatch;
  LED1 <= 1;

  rec_e7m[cycle]  <= e7m;
  rec_bas[cycle]  <= bas;  // ~ 5 e7m blocks ~ 250ns, little ripples
  rec_read[cycle] <= read;
  rec_buds[cycle] <= buds;
  rec_doe[cycle]  <= doe;
  
  rec_doe_latched[cycle]  <= doe_latched;
  rec_z_host_write[cycle]  <= z_host_write;
  rec_bslaven[cycle]  <= bslaven;
      
  if (sel_data) begin
    if (z_cycle < 6) begin 
      sel_addr <= 0;
      
      if (z_cycle==0) begin
        z_addr[23:0] <= 0;
      end
      
      if (z_cycle>0) begin
        //z_addr[17] <= 0; //z_host[7];
        if (z_host[6]==1) z_addr[18] <= 1; //z_host[6];
        if (z_host[5]==1) z_addr[19] <= 1; //z_host[5];
        if (z_host[4]==1) z_addr[20] <= 1; //z_host[4];
        if (z_host[2]==1) z_addr[21] <= 1; //z_host[2]; // oops swapped
        if (z_host[3]==1) z_addr[22] <= 1; //z_host[3]; // .... .......
        if (z_host[1]==1) z_addr[23] <= 1; //z_host[1];
      end
    end else begin
      //sel_addr <= 1;
      if ((z_addr&'hffff00)=='he80000) z_addrmatch <= 1;
      // dont sample inside of switching time
      if (z_cycle==10) begin
        /*z_addr[9]  <= 0; //z_host[15];
        z_addr[10] <= z_host[14];
        z_addr[11] <= z_host[13];
        z_addr[12] <= z_host[12]; 
        z_addr[13] <= z_host[11];
        z_addr[14] <= z_host[10];
        z_addr[15] <= z_host[9];
        z_addr[16] <= z_host[8];
        
        z_addr[1] <= z_host[7];
        z_addr[2] <= z_host[6];
        z_addr[3] <= z_host[5];
        z_addr[4] <= z_host[4];
        z_addr[5] <= z_host[3];
        z_addr[6] <= z_host[2];
        z_addr[7] <= z_host[1];
        z_addr[8] <= z_host[0];*/
        
        z_addr_buffer <= z_addr;
      end else if (z_cycle==11) begin
        /*case (z_addr & 'h0000ff)
          'h000000: z_data <= 'b1100_0000_0000_0000; // zorro 2
          'h000002: z_data <= 'b0111_0000_0000_0000; // 4mb, not linked
          'h000004: z_data <= 'b0001_0000_0000_0000; // product number
          'h000006: z_data <= 'b0111_0000_0000_0000; // (23)

          'h000008: z_data <= 'b0100_0000_0000_0000; // flags
          'h00000a: z_data <= 'b0000_0000_0000_0000; // sub size automatic

          'h00000c: z_data <= 'b0000_0000_0000_0000; // reserved
          'h00000e: z_data <= 'b0000_0000_0000_0000; // 

          'h000010: z_data <= 'b0110_0000_0000_0000; // manufacturer high byte
          'h000012: z_data <= 'b1101_0000_0000_0000; // 
          'h000014: z_data <= 'b0110_0000_0000_0000; // manufacturer low byte
          'h000016: z_data <= 'b1101_0000_0000_0000;

          'h000018: z_data <= 'b0000_0000_0000_0000; // reserved
          'h00001a: z_data <= 'b0000_0000_0000_0000; //

          'h000044: z_state <= Z_CONF_DONE;
         
          default: z_data <= 'b0000_0000_0000_0000;	 
        endcase*/
        //z_data <= 'b0000_0000_0000_0000;
        
      end
    end
  end //else
    //sel_addr <= 0;
  
  rec_addr23[cycle] <= z_addr[23];
  rec_addr22[cycle] <= z_addr[22];
  rec_addr21[cycle] <= z_addr[21];
  rec_addr20[cycle] <= z_addr[20];
  rec_addr19[cycle] <= z_addr[19];
  rec_addr18[cycle] <= z_addr[18];
  rec_addr17[cycle] <= z_addr[17];
  rec_addr16[cycle] <= z_addr[16];
  rec_addr15[cycle] <= z_addr[15];
  rec_addr14[cycle] <= z_addr[14];
  rec_addr13[cycle] <= z_addr[13];
  rec_addr12[cycle] <= z_addr[12];
  rec_addr11[cycle] <= z_addr[11];
  rec_addr10[cycle] <= z_addr[10];
  rec_addr9[cycle] <= z_addr[9];
  rec_addr8[cycle] <= z_addr[8];
  rec_addr7[cycle] <= z_addr[7];
  rec_addr6[cycle] <= z_addr[6];
  rec_addr5[cycle] <= z_addr[5];
  rec_addr4[cycle] <= z_addr[4];
  rec_addr3[cycle] <= z_addr[3];
  rec_addr2[cycle] <= z_addr[2];
  rec_addr1[cycle] <= z_addr[1];
  
  rec_zcycle[cycle] <= z_cycle>0?1:0;
  
  rec_addrmatch[cycle] <= z_addrmatch;
  
  if (rt_cycle<1200) rt_cycle <= rt_cycle+1;
  else if ((counter_x==0 && counter_y==0) && !read) begin
    rt_cycle<=0;
    z_data <= counter_frame;
  end
  cycle <= rt_cycle>>1;
  
  if (doe && !doe_latched) begin
    doe_latched <= 1; 
  end
  
  if (z_cycle>79) z_cycle<=0;
    else z_cycle <= z_cycle + 1;
  
  // debounce this
  if (!doe && bas) begin
    if (z_debounce>0) begin
      z_cycle <= 0; // sync to doe
      doe_latched <= 0;
      z_addrmatch <= 0;
      z_addr_buffer <= 0;
      z_addr <= 0;
      z_debounce <= 0;
    end else begin
      z_debounce <= z_debounce + 1;
    end
  end
  
end

// 200mhz = 5ns
// 100mhz = 10ns
/*
assign host_high = C9;

reg [9:0] fetch_x;
reg fetching;

always @(posedge sdram_clk)
begin
ram_byte_enable <= 'b1111;
ram_enable <= 1;

if (host_high)
 high_ram_addr <= host_addr;

// TODO: ACK, buffer until overscan/sync porch
if (host_latch && cmd_ready)
 begin
  //ram_addr <= (counter_frame & 'b111111110000)>>2;
  ram_addr <= ((high_ram_addr&'b11110000)<<10) | ((high_ram_addr&'b1111)<<4) | ((host_addr&'b11110000)<<6) | (host_addr&'b1111) | (high_bit1<<8) | (high_bit2<<18); //&'b1111111100;
  // write cycle
  if (host_pixel == 1)
	begin
	 ram_data_in <= 'hffffffff;
    ram_write <= 1;
	 ram_enable <= 1;
	 written <= 1;
	end
  else
	begin
	 ram_data_in <= 'hf0000000;
    ram_write <= 1;
	 ram_enable <= 1;
	 written <= 1;
	end
 end
else
 begin
  if (cmd_ready && fetching)
  begin
	 // read cycles
	 ram_addr <= ((counter_y << 10) | (fetch_x));
	 ram_write <= 0;
  end
  
  if (data_out_ready)
  begin
    ram_data_buffer[fetch_x] <= ram_data_out;
	 fetch_x <= fetch_x + 1;
	 if (fetch_x > 639)
	 begin
	   fetch_x <= 0;
		fetching <= 0;
	 end
  end
  
  if (counter_x == 0) begin
    fetch_x <= 0;
    fetching <= 1;
  end
 end
end

assign LED1=host_latch;
*/

assign hsync = ~vga_HS;
assign vsync = ~vga_VS;

always @(posedge CLK_IN1)
  vgaclock <= ~vgaclock;


/*	  red   <= ~vga_HS & ~vga_VS & ram_data_buffer[counter_x][0];
	  green <= ~vga_HS & ~vga_VS & ram_data_buffer[counter_x][1];
	  blue  <= ~vga_HS & ~vga_VS & ram_data_buffer[counter_x][2];*/

always @(posedge clk) begin
  if(counter_xmaxed)
	 begin
		counter_x <= 0;
		counter_y <= counter_y + 1;
	 end
  else
    counter_x <= counter_x + 1;

  if(counter_y==0 && counter_xmaxed) begin
    counter_frame <= counter_frame + 1;
  end

  vga_HS <= (counter_x[9:4]==0);   // active for 16 clocks
  vga_VS <= (counter_y==0);   // active for 768 clocks

  if (counter_x < 640) begin
	  if ((vga_HS | vga_VS))
	    rgb <= 0;
	    
	  else begin
      if (counter_y>464)
        rgb <= rec_zcycle[counter_x]?'h0ff0:0;
      else if (counter_y>454)
        rgb <= rec_doe_latched[counter_x]?'hf00f:0;
      else if (counter_y>444)
        rgb <= rec_addrmatch[counter_x]?'hffff:0;
      else if (counter_y>434)
        rgb <= rec_z_host_write[counter_x]?'hffff:0;
        
      else if (counter_y>426)
        rgb <= rec_addr1[counter_x]||counter_y==427?'hf0:0;
      else if (counter_y>418)
        rgb <= rec_addr2[counter_x]||counter_y==419?'hf0:0;
      else if (counter_y>410)
        rgb <= rec_addr3[counter_x]||counter_y==411?'hf0:0;
      else if (counter_y>402)
        rgb <= rec_addr4[counter_x]||counter_y==403?'hf0:0;
      else if (counter_y>394)
        rgb <= rec_addr5[counter_x]||counter_y==395?'hf0:0;
      else if (counter_y>386)
        rgb <= rec_addr6[counter_x]||counter_y==387?'hf0:0;
      else if (counter_y>378)
        rgb <= rec_addr7[counter_x]||counter_y==379?'hf0:0;
        
      else if (counter_y>370)
        rgb <= rec_addr8[counter_x]||counter_y==371?'h0f:0;
      else if (counter_y>362)
        rgb <= rec_addr9[counter_x]||counter_y==363?'hf0:0;
      else if (counter_y>354)
        rgb <= rec_addr10[counter_x]||counter_y==355?'hf0:0;
      else if (counter_y>346)
        rgb <= rec_addr11[counter_x]||counter_y==347?'hf0:0;
      else if (counter_y>338)
        rgb <= rec_addr12[counter_x]||counter_y==339?'hf0:0;
      else if (counter_y>330)
        rgb <= rec_addr13[counter_x]||counter_y==331?'hf0:0;
      else if (counter_y>322)
        rgb <= rec_addr14[counter_x]||counter_y==323?'hf0:0;
      else if (counter_y>314)
        rgb <= rec_addr15[counter_x]||counter_y==315?'hf0:0;
        
      else if (counter_y>306)
        rgb <= rec_addr16[counter_x]||counter_y==307?'h0f:0;
      else if (counter_y>298)
        rgb <= rec_addr17[counter_x]||counter_y==299?'hf0:0;
      else if (counter_y>290)
        rgb <= rec_addr18[counter_x]||counter_y==291?'hf0:0;
      else if (counter_y>282)
        rgb <= rec_addr19[counter_x]||counter_y==283?'hf0:0;
      else if (counter_y>274)
        rgb <= rec_addr20[counter_x]||counter_y==275?'hf0:0;
      else if (counter_y>266)
        rgb <= rec_addr21[counter_x]||counter_y==267?'hf0:0;
      else if (counter_y>258)
        rgb <= rec_addr22[counter_x]||counter_y==259?'hf0:0;
      else if (counter_y>250)
        rgb <= rec_addr23[counter_x]||counter_y==251?'hf0:0;
    
      else if (counter_y>220)
        rgb <= rec_e7m[counter_x]?'hff:0;
      else if (counter_y>200)
        rgb <= rec_bas[counter_x]?'hee:0;
      else if (counter_y>150)
        rgb <= rec_buds[counter_x]?'hff:0;
      else if (counter_y>100)
        rgb <= rec_read[counter_x]?'hee:0;
      else if (counter_y>50)
        rgb <= rec_doe[counter_x]?'hff:0;
      else
        rgb <= 0;
      end
  end
end

endmodule
