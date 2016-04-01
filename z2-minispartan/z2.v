`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:49:19 03/22/2016 
// Design Name: 
// Module Name:    z2 
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
module z2(

input CLK50,

// zorro
input znCFGIN,
//output znCFGOUT,
output znSLAVEN,
input znBERR,
input znRST,
input zE7M,
input zREAD,
input zDOE,

// address bus
input znAS,
input znUDS,
input znLDS,
input zA1,
input zA2,
input zA3,
input zA4,
input zA5,
input zA6,
input zA7,
input zA8,
input zA9,
input zA10,
input zA11,
input zA12,
input zA13,
input zA14,
input zA15,
input zA16,
input zA17,
input zA18,
input zA19,
input zA20,
input zA21,
input zA22,
input zA23,

// data bus
output zDIR,
inout zD0,
inout zD1,
inout zD2,
inout zD3,
inout zD4,
inout zD5,
inout zD6,
inout zD7,
inout zD8,
inout zD9,
inout zD10,
inout zD11,
inout zD12,
inout zD13,
inout zD14,
inout zD15,

// vga debug out
/*output vgaR,
output vgaG,
output vgaB,
output vgaVSync,
output vgaHSync,*/

// leds
output reg [7:0] LEDS,

// SDRAM
output SDRAM_CLK,  
output SDRAM_CKE,  
output SDRAM_nCS,   
output SDRAM_nRAS,  
output SDRAM_nCAS,
output SDRAM_nWE,   
output [1:0]  SDRAM_DQM,  
output [12:0] A, 
output [1:0]  SDRAM_BA,
inout  [15:0] D,

// HDMI
output [3:0] TMDS_out_P,
output [3:0] TMDS_out_N
);

clk_wiz_v3_6 DCM(
  .CLK_IN1(CLK50),
  .CLK_OUT100(z_sample_clk),
  .CLK_OUT75(vga_clk)
);

/*vga_clocking vga_clocking(
  .clk50(CLK50),
  .pixel_clock(vga_clk)
);*/

wire sdram_reset;
reg  ram_enable;
reg  [23:0] ram_addr;
wire [31:0] ram_data_out;
wire data_out_ready;
reg  [31:0] ram_data_in;
reg  ram_write;
reg  [3:0]  ram_byte_enable;
reg  [15:0] ram_data_buffer [0:1023]; // 640x16bit packed as 320x32bit
reg  [10:0] fetch_x = 0;
reg  fetching;


// SDRAM
SDRAM_Controller_v sdram(
  .clk(z_sample_clk),   
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
  .SDRAM_CS(SDRAM_nCS), 
  .SDRAM_RAS(SDRAM_nRAS),
  .SDRAM_CAS(SDRAM_nCAS),
  .SDRAM_WE(SDRAM_nWE),   
  .SDRAM_DATA(D),
  .SDRAM_ADDR(A),
  .SDRAM_DQM(SDRAM_DQM),
  .SDRAM_BA(SDRAM_BA) 
);

reg [7:0] red_p;
reg [7:0] green_p;
reg [7:0] blue_p;
reg dvi_vsync;
reg dvi_hsync;
reg dvi_blank;

reg [3:0] tmds_out_pbuf;
reg [3:0] tmds_out_nbuf;

assign TMDS_out_P = tmds_out_pbuf;
assign TMDS_out_N = tmds_out_nbuf;

dvid_out dvid_out(
  // Clocking
  .clk_pixel(vga_clk),
  // VGA signals
  .red_p(red_p),
  .green_p(green_p),
  .blue_p(blue_p),
  .blank(dvi_blank),
  .hsync(dvi_hsync),
  .vsync(dvi_vsync),
  // TMDS outputs
  .tmds_out_p(tmds_out_pbuf),
  .tmds_out_n(tmds_out_nbuf)
);

assign sdram_reset = 0;

// vga registers
reg [11:0] counter_x;
reg [11:0] counter_y;
//reg [11:0] counter_frame;

parameter h_rez        = 1280;
parameter h_sync_start = h_rez+72;
parameter h_sync_end   = h_rez+80;
parameter h_max        = 1647;

parameter v_rez        = 720;
parameter v_sync_start = v_rez+3;
parameter v_sync_end   = v_rez+3+5;
parameter v_max        = 749;

reg [23:0] zaddr;
reg [15:0] data;
reg [15:0] data_in;
reg dataout;

assign zDIR     = ~(zREAD);
assign znSLAVEN = ~(dataout & zDOE & zREAD & !znAS && (zaddr>=ram_low && zaddr<ram_high));
assign zD0  = zREAD?data[0]:1'bz;
assign zD1  = zREAD?data[1]:1'bz;
assign zD2  = zREAD?data[2]:1'bz;
assign zD3  = zREAD?data[3]:1'bz;
assign zD4  = zREAD?data[4]:1'bz;
assign zD5  = zREAD?data[5]:1'bz;
assign zD6  = zREAD?data[6]:1'bz;
assign zD7  = zREAD?data[7]:1'bz;
assign zD8  = zREAD?data[8]:1'bz;
assign zD9  = zREAD?data[9]:1'bz;
assign zD10 = zREAD?data[10]:1'bz;
assign zD11 = zREAD?data[11]:1'bz;
assign zD12 = zREAD?data[12]:1'bz;
assign zD13 = zREAD?data[13]:1'bz;
assign zD14 = zREAD?data[14]:1'bz;
assign zD15 = zREAD?data[15]:1'bz;

reg [23:0] last_addr = 0;
reg [15:0] last_data = 0;
reg [1:0] last_ds = 0;

/*reg last_uds = 0;
reg last_lds = 0;
reg last_as = 0;
reg last_read = 0;*/
reg host_reading = 0;
reg write_clocked = 0;
reg byte_ena_clocked = 0;

parameter max_fill = 512;

reg [25:0] writeq_addr [0:max_fill-1]; // 25=uds 24=lds
reg [15:0] writeq_data [0:max_fill-1];
reg [10:0] writeq_fill;
reg [10:0] writeq_drain;

reg [3:0] zclk;
assign z_rising = (zclk[0]==1 && zclk[1]==0) || (zclk[3]==1 && zclk[2]==0);

reg [3:0] state = 0;
reg row_fetched = 0;
parameter IDLE = 0;
parameter WAIT_READ = 1;
parameter WAIT_WRITE = 2;
parameter WAIT_WRITE2 = 3;
parameter WAIT_WRITE3 = 4;
parameter WAIT_READ2 = 5;

parameter ram_low = 'h200000;
parameter ram_high = 'h340000;

always @(posedge z_sample_clk) begin

  // sync to zorro clock (z_rising)
  zclk[0] <= znUDS;
  zclk[1] <= zclk[0];
  zclk[2] <= znLDS;
  zclk[3] <= zclk[2];

  data_in[0] <= zD0;
  data_in[1] <= zD1;
  data_in[2] <= zD2;
  data_in[3] <= zD3;
  data_in[4] <= zD4;
  data_in[5] <= zD5;
  data_in[6] <= zD6;
  data_in[7] <= zD7;
  data_in[8] <= zD8;
  data_in[9] <= zD9;
  data_in[10] <= zD10;
  data_in[11] <= zD11;
  data_in[12] <= zD12;
  data_in[13] <= zD13;
  data_in[14] <= zD14;
  data_in[15] <= zD15;
  
  zaddr[23] <= zA23;
  zaddr[22] <= zA22;
  zaddr[21] <= zA21;
  zaddr[20] <= zA20;
  zaddr[19] <= zA19;
  zaddr[18] <= zA18;
  zaddr[17] <= zA17;
  zaddr[16] <= zA16;
  zaddr[15] <= zA15;
  zaddr[14] <= zA14;
  zaddr[13] <= zA13;
  zaddr[12] <= zA12;
  zaddr[11] <= zA11;
  zaddr[10] <= zA10;
  zaddr[9] <= zA9;
  zaddr[8] <= zA8;
  zaddr[7] <= zA7;
  zaddr[6] <= zA6;
  zaddr[5] <= zA5;
  zaddr[4] <= zA4;
  zaddr[3] <= zA3;
  zaddr[2] <= zA2;
  zaddr[1] <= zA1;
  zaddr[0] <= 0;
  
  if (state == IDLE) begin
  
    ram_write <= 0;
    dataout <= 0;
  
    if (zREAD && !znAS && zaddr>=ram_low && zaddr<ram_high) begin
      // read RAM
      ram_addr <= ((zaddr&'h1fffff)<<1);
      dataout <= 1;
      data <= ram_data_out[15:0];
      ram_enable <= 1;
      ram_write <= 0;
      if (zDOE) state <= WAIT_READ;
    
    end else if (zREAD && !znAS && zaddr=='he80000) begin
      // read iospace
      dataout <= 1;
      data <= max_fill-writeq_fill;
      
    end else if (!zREAD && z_rising && zaddr>=ram_low && zaddr<ram_high) begin
      // write RAM
        dataout <= 0;
        
        //if (last_addr!=zaddr || last_data!=data_in || last_ds!={znLDS,znUDS}) begin
          last_addr <= zaddr;
          last_data <= data_in;
          last_ds <= {znLDS,znUDS};
          writeq_addr[writeq_fill][23:0] <= zaddr;
          writeq_addr[writeq_fill][24]   <= ~znLDS;
          writeq_addr[writeq_fill][25]   <= ~znUDS;
          writeq_data[writeq_fill]       <= data_in;
          
          if (writeq_fill<max_fill-1)
            writeq_fill <= writeq_fill+1;
          else
            writeq_fill <= 0;
        //end
      // FIXME end signal lose data
    end else if (!row_fetched && !fetching && counter_y<600) begin
      fetching <= 1;
      fetch_x <= 0;
      ram_byte_enable <= 'b1111;
      ram_addr  <= ((counter_y << 10));
      ram_write <= 0;
      ram_enable <= 1;
    end
  
  end else if (state == WAIT_READ) begin
    dataout <= 1;
    data <= ram_data_out[15:0];
    ram_enable <= 0;
    if (!zDOE || znAS) state <= IDLE;
    
  end else if (state == WAIT_WRITE) begin
    ram_enable <= 0;
    
    if (writeq_drain<max_fill-1)
      writeq_drain <= writeq_drain+1;
    else
      writeq_drain <= 0;
    
    if (cmd_ready) begin
      state <= IDLE;
    end
  end
  
  if (fetching && state == IDLE) begin
    // read window
    
    ram_data_buffer[fetch_x] <= ram_data_out[15:0];
    ram_byte_enable <= 'b1111;
    ram_write <= 0;
    ram_enable <= 1;
    
    if (data_out_ready) begin
      ram_addr  <= ((counter_y << 10) | fetch_x)<<2;
      
      fetch_x <= fetch_x + 1;
      if (fetch_x > 1023) begin
        fetching <= 0;
        fetch_x  <= 0;
        row_fetched <= 1;
        ram_enable <= 0;
      end
    end
  end
  
  if (!fetching && state == IDLE && cmd_ready && writeq_fill!=writeq_drain) begin
    // write window
    if (writeq_addr[writeq_drain][25] && !writeq_addr[writeq_drain][24])
      ram_byte_enable <= 'b1010; // UDS
    else if (writeq_addr[writeq_drain][24] && !writeq_addr[writeq_drain][25])
      ram_byte_enable <= 'b0101; // LDS
    else
      ram_byte_enable <= 'b1111;
    //                       ^^-- currently visible bytes
    
    ram_data_in <= (writeq_data[writeq_drain]<<16)|(writeq_data[writeq_drain]);
    ram_addr    <= (((writeq_addr[writeq_drain][23:0])&'h1ffffe)<<1); // store 16 bit in 32 bit cell      
    ram_write   <= 1;
    ram_enable  <= 1;
    
    /*last_addr <= writeq_addr[writeq_drain][23:0]; //zaddr;
    last_data <= writeq_data[writeq_drain]; //data_in;
    last_lds  <= writeq_addr[writeq_drain][24]; //~znLDS;
    last_uds  <= writeq_addr[writeq_drain][25]; //~znUDS;*/
    
    state <= WAIT_WRITE;
  end
  
  if (counter_x==0)
    row_fetched <= 0;
end

/*assign vgaHSync = ~hs;
assign vgaVSync = ~vs;*/

reg[15:0] rgb = 'h0000;

/*assign vgaR = rgb[0];
assign vgaG = rgb[5];
assign vgaB = rgb[11];*/

always @(posedge vga_clk) begin
  if (counter_x == h_max) begin
    counter_x <= 0;
    if (counter_y == v_max)
      counter_y <= 0;
    else
      counter_y <= counter_y + 1;
  end else
    counter_x <= counter_x + 1;
    
  if (counter_x>=h_sync_start && counter_x<h_sync_end)
    dvi_hsync <= 1;
  else
    dvi_hsync <= 0;
    
  if (counter_y>=v_sync_start && counter_y<v_sync_end)
    dvi_vsync <= 1;
  else
    dvi_vsync <= 0;
      
  if (counter_x<h_rez && counter_y<v_rez) begin
    /*red_p <= 'hff;
    green_p <= 'hff;
    blue_p <= 'hff;*/
    rgb <= ram_data_buffer[counter_x];
    dvi_blank <= 0;
  end else begin
    dvi_blank <= 1;
    /*red_p <= 0;
    green_p <= 0;
    blue_p <= 0;*/
    rgb <= 0;
  end

  red_p[7:3]   <= rgb[15:11];
  green_p[7:2] <= rgb[10:5];
  blue_p[7:3]  <= rgb[4:0];

  red_p[2] <= rgb[11];
  red_p[1] <= rgb[11];
  red_p[0] <= rgb[11];
  green_p[1] <= rgb[5];
  green_p[0] <= rgb[5];
  blue_p[2] <= rgb[0];
  blue_p[1] <= rgb[0];
  blue_p[0] <= rgb[0];

  /*if (counter_y==0 && (counter_x >= h_max)) begin
    counter_frame <= counter_frame + 1;
  end*/
  LEDS <= 0;
	//rgb <= 0;
  
  if (dvi_blank)
	    rgb <= 0;
	  else
      //rgb <= ram_data_buffer[counter_x];
        
      if (counter_y>600) begin
        if (counter_x<210)
          rgb <= 0;
        else if (counter_x<220)
          rgb <= last_addr[23]?16'hff:16'h0;
        else if (counter_x<230)
          rgb <= last_addr[22]?16'hff:16'h0;
        else if (counter_x<240)
          rgb <= last_addr[21]?16'hff:16'h0;
        else if (counter_x<250)
          rgb <= last_addr[20]?16'hff:16'h0;
        else if (counter_x<260)
          rgb <= last_addr[19]?16'hff:16'h0;
        else if (counter_x<270)
          rgb <= last_addr[18]?16'hff:16'h0;
        else if (counter_x<280)
          rgb <= last_addr[17]?16'hff:16'h0;
        else if (counter_x<290)
          rgb <= last_addr[16]?16'hff:16'h0;
        else if (counter_x<300)
          rgb <= last_addr[15]?16'hff:16'h0;
        else if (counter_x<310)
          rgb <= last_addr[14]?16'hff:16'h0;
        else if (counter_x<320)
          rgb <= last_addr[13]?16'hff:16'h0;
        else if (counter_x<330)
          rgb <= last_addr[12]?16'hff:16'h0;
        else if (counter_x<340)
          rgb <= last_addr[11]?16'hff:16'h0;
        else if (counter_x<350)
          rgb <= last_addr[10]?16'hff:16'h0;
        else if (counter_x<360)
          rgb <= last_addr[9]?16'hff:16'h0;
        else if (counter_x<370)
          rgb <= last_addr[8]?16'hff:16'h0;
        else if (counter_x<380)
          rgb <= last_addr[7]?16'hff:16'h0;
        else if (counter_x<390)
          rgb <= last_addr[6]?16'hff:16'h0;
        else if (counter_x<400)
          rgb <= last_addr[5]?16'hff:16'h0;
        else if (counter_x<410)
          rgb <= last_addr[4]?16'hff:16'h0;
        else if (counter_x<420)
          rgb <= last_addr[3]?16'hff:16'h0;
        else if (counter_x<430)
          rgb <= last_addr[2]?16'hff:16'h0;
        else if (counter_x<440)
          rgb <= last_addr[1]?16'hff:16'h0;
        else if (counter_x<450)
          rgb <= last_addr[0]?16'hff:16'h0;
        else if (counter_x<490)
          rgb <= 16'h0;
        /*else if (counter_x<500)
          rgb <= last_uds?16'hf00f:16'hffff;
        else if (counter_x<510)
          rgb <= last_lds?16'hf00f:16'hffff;*/
          
        else if (counter_x<520)
          rgb <= last_data[15]?16'hffff:16'h00ff;
        else if (counter_x<521)
          rgb <= 0;
        else if (counter_x<530)
          rgb <= last_data[14]?16'hffff:16'h00ff;
        else if (counter_x<531)
          rgb <= 0;
        else if (counter_x<540)
          rgb <= last_data[13]?16'hffff:16'h00ff;
        else if (counter_x<541)
          rgb <= 0;
        else if (counter_x<550)
          rgb <= last_data[12]?16'hffff:16'h00ff;
        else if (counter_x<551)
          rgb <= 0;
        else if (counter_x<560)
          rgb <= last_data[11]?16'hffff:16'h00ff;
        else if (counter_x<561)
          rgb <= 0;
        else if (counter_x<570)
          rgb <= last_data[10]?16'hffff:16'h00ff;
        else if (counter_x<571)
          rgb <= 0;
        else if (counter_x<580)
          rgb <= last_data[9]?16'hffff:16'h00ff;
        else if (counter_x<581)
          rgb <= 0;
        else if (counter_x<590)
          rgb <= last_data[8]?16'hffff:16'h00ff;
        else if (counter_x<591)
          rgb <= 0;
        else if (counter_x<600)
          rgb <= last_data[7]?16'hffff:16'h00ff;
        else if (counter_x<601)
          rgb <= 0;
        else if (counter_x<610)
          rgb <= last_data[6]?16'hffff:16'h00ff;
        else if (counter_x<611)
          rgb <= 0;
        else if (counter_x<620)
          rgb <= last_data[5]?16'hffff:16'h00ff;
        else if (counter_x<621)
          rgb <= 0;
        else if (counter_x<630)
          rgb <= last_data[4]?16'hffff:16'h00ff;
        else if (counter_x<631)
          rgb <= 0;
        else if (counter_x<640)
          rgb <= last_data[3]?16'hffff:16'h00ff;
        else if (counter_x<641)
          rgb <= 0;
        else if (counter_x<650)
          rgb <= last_data[2]?16'hffff:16'h00ff;
        else if (counter_x<651)
          rgb <= 0;
        else if (counter_x<660)
          rgb <= last_data[1]?16'hffff:16'h00ff;
        else if (counter_x<661)
          rgb <= 0;
        else if (counter_x<670)
          rgb <= last_data[0]?16'hffff:16'h00ff;
        else if (counter_x<700)
          rgb <= 0;
        /*else if (counter_x<710)
          rgb <= last_as?16'hf0ff:16'hffff;
        else if (counter_x<720)
          rgb <= last_read?16'hf0ff:16'hffff;*/
        else if (counter_x<(700+max_fill)) begin
          if (counter_y<550) 
            rgb <= writeq_fill>(counter_x-700)?16'hffff:16'h0000;        
          else
            rgb <= writeq_drain>(counter_x-700)?16'hffff:16'h0000;
        end else 
          rgb <= 0;
        end
      else begin
        if (counter_x>1023)
          rgb <= 0;
        else 
          rgb <= ram_data_buffer[counter_x];
      end

end

endmodule
