`timescale 1ns / 1ns
// Company: MNT Media and Technology UG
// Engineer: Lukas F. Hartmann (@mntmn)
// Create Date:    21:49:19 03/22/2016 
// Design Name:    Amiga 2000/3000/4000 Graphics Card (VA2000)
// Module Name:    z2
// Target Devices: 

module z2(
input CLK50,

// zorro
input znCFGIN,
output znCFGOUT,
output znSLAVEN,
output zXRDY,
input znBERR,
input znRST,
input zE7M,
input zREAD,
input zDOE,

// z3
input zSENSEZ3,
input znFCS,
input zFC0,
input zFC1,
input zFC2,
input znDS0,
input znDS1,
output znCINH,
output znDTACK,

// address bus
input znAS,
input znUDS, // ds2+ds3
input znLDS,
inout [22:0] zA,

// data bus
output zDIR1,
output zDIR2,
output zDIR3,
output zDIR4,
inout [15:0] zD,

// SD
output SD_nCS,
output SD_MOSI,
input  SD_MISO,
output SD_SCLK,
input SD_DAT1,
input SD_DAT2,

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

`ifdef SIMULATION
,
input z_sample_clk,
input vga_clk
`endif
);

reg clk_reset=0;

`ifndef SIMULATION
clk_wiz_v3_6 DCM(
  .CLK_IN1(CLK50),
  .CLK_OUT1(z_sample_clk),
  .CLK_OUT2(vga_clk_100),
  .CLK_OUT3(vga_clk_75),
  .CLK_OUT4(vga_clk_50),
  .LOCKED(clock_locked)
);

reg [1:0] vga_clk_sel = 0;

// pixel clock selector
// 00 == 75mhz
// 01 == 50mhz
// 11 == 100mhz

/*BUFGMUX #(.CLK_SEL_TYPE("ASYNC")) vga_clk_mux1(
  .O(vga_clk_step1), 
  .I0(vga_clk_50),
  .I1(vga_clk_100),
  .S(vga_clk_sel[1])
);*/

// #(.CLK_SEL_TYPE("ASYNC")) 
BUFGMUX vga_clk_mux2(
  .O(vga_clk), 
  .I0(vga_clk_75),
  .I1(vga_clk_50),
  .S(vga_clk_sel[0])
);

// sd card interface
reg sd_reset = 0;
reg sd_read = 0;
reg sd_write = 0;
reg sd_continue = 0;

reg [31:0] sd_addr_in = 0;
reg [7:0] sd_data_in = 0;
reg sd_handshake_in = 0;

wire sd_busy;
wire [7:0] sd_data_out;
wire [15:0] sd_error;
wire sd_handshake_out;

wire [15:0] sd_clkdiv;

SdCardCtrl sdcard(
  .clk_i(z_sample_clk),
  .reset_i(sd_reset),
  .rd_i(sd_read),
  .wr_i(sd_write),
  .continue_i(sd_continue),
  .addr_i(sd_addr_in),
  .data_i(sd_data_in),
  .data_o(sd_data_out),
  .busy_o(sd_busy),
  .error_o(sd_error),
  
  .cs_bo(SD_nCS),
  .mosi_o(SD_MOSI),
  .miso_i(SD_MISO),
  .sclk_o(SD_SCLK),
  
  .hndShk_i(sd_handshake_in),
  .hndShk_o(sd_handshake_out),
  
  .clkdiv_o(sd_clkdiv)
);

`endif

reg  sdram_reset = 0;
reg  ram_enable = 0;
reg  [23:0] ram_addr = 0;
wire [15:0] ram_data_out;
wire data_out_ready;
wire data_out_queue_empty;
wire [4:0] sdram_state;
wire sdram_btb;
reg  [15:0] ram_data_in;
reg  ram_write = 0;
reg  ram_burst = 0;
reg  [1:0]  ram_byte_enable;

reg  [15:0] fetch_buffer [0:1999];
reg  [11:0] fetch_x = 0;
reg  [11:0] fetch_x2 = 0;

reg  [23:0] fetch_y = 0;
reg  [23:0] pan_ptr = 0;
reg  fetching = 0;

reg display_enable = 1;
//reg [15:0] copy_glitch_reg2 = 'h580; // magic value

reg [10:0] glitchx2_reg = 'h1fd; // better 1fc in 8bit?
reg [8:0]  ram_burst_col = 'h1fe; //'b111111010;
reg burst_enabled = 1; // toggle ram burst mode on/off
reg [10:0] fetch_preroll = 64;

reg [15:0] row_pitch = 2048;
reg [4:0] row_pitch_shift = 11; // 2048 = 1<<11

// custom refresh mechanism
reg [15:0] refresh_counter = 0;
reg [23:0] refresh_addr = 0;
reg [15:0] refresh_time = 'h1000;

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
  .burst_col(ram_burst_col),
  .burst(ram_burst),
  
  // read data port
  .data_out(ram_data_out),
  .data_out_ready(data_out_ready),
  .data_out_queue_empty(data_out_queue_empty),

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

// dvi out
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
reg dvid_reset = 0;

`ifndef SIMULATION
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
  .tmds_out_n(tmds_out_nbuf),
  .reset(dvid_reset)
);
`endif

// vga registers
reg [11:0] counter_x = 0;
reg [11:0] counter_y = 0;
reg [11:0] display_x = 0;
reg [11:0] display_x2 = 0;
reg [11:0] display_x3 = 0;

// modeline
reg [11:0] h_rez        = 1280;
reg [11:0] h_sync_start = 1280+72;
reg [11:0] h_sync_end   = 1280+80;
reg [11:0] h_max        = 1647;
reg [11:0] v_rez        = 720;
reg [11:0] v_sync_start = 720+3;
reg [11:0] v_sync_end   = 720+8;
reg [11:0] v_max        = 749;
reg [11:0] screen_w = 1280;
reg [11:0] screen_h = 720;

// zorro port buffers / flags
reg ZORRO3 = 1;
reg [23:0] zaddr; // zorro 2 address
reg [31:0] zaddr_sync;
reg [31:0] zaddr_sync2;
reg [23:0] z2_mapped_addr;
reg [15:0] data;
reg [15:0] data_in;
reg [15:0] regdata_in;
reg [15:0] data_z3_hi16;
reg [15:0] data_z3_low16;
reg [15:0] data_in_z3_low16;
reg [15:0] zdata_in_sync;
reg [15:0] z3_din_high_s2;
reg [15:0] z3_din_low_s2;
reg [31:0] z3addr;
reg [31:0] z3addr2;
reg [31:0] z3_mapped_addr;
reg [31:0] z3_read_addr;
reg [15:0] z3_read_data;
reg [15:0] z3_regread_hi;
reg [15:0] z3_regread_lo;

reg z2_snoop_reset_mode = 1;
reg z_confout = 0;
assign znCFGOUT = znCFGIN?1'b1:(~z_confout); //?1'bZ:1'b0;

// zorro data output stages
reg dataout = 0;
reg dataout_z3 = 0;
reg dataout_enable = 0;
reg slaven = 0;
reg dtack = 0;

// level shifter direction pins
assign zDIR1     = (dataout_enable | dataout_z3); // d2-d9
assign zDIR2     = (dataout_enable | dataout_z3); // d10-15, d0-d1
assign zDIR3     = dataout_z3; // a16-a23 <- input
assign zDIR4     = dataout_z3; // a8-a15 <- input

reg z_ready = 'b1;
assign zXRDY  = z_ready?1'bZ:1'b0; //works only if bZ?
assign znCINH = 1; //1'bZ; //0; // Z2 = /OVR

assign znSLAVEN = (dataout && slaven)?1'b0:1'b1;
assign znDTACK  = dtack?1'b0:1'bZ;

assign zD  = (dataout_z3) ? data_z3_hi16 : (dataout ? data : 16'bzzzz_zzzz_zzzz_zzzz); // data = Z2: full 16 bit or Z3: upper 16 bit
assign zA  = (dataout_z3) ? {data_z3_low16, 7'bzzzz_zzz} : 23'bzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

// autoconf status
reg z3_confdone = 0;

// zorro synchronizers
// (inspired by https://github.com/endofexclusive/greta/blob/master/hdl/bus_interface/bus_interface.vhdl)

reg [4:0] znAS_sync  = 5'b11111;
reg [2:0] znFCS_sync = 3'b111;
reg [2:0] znUDS_sync = 3'b000;
reg [2:0] znLDS_sync = 3'b000;
reg [2:0] znDS1_sync = 3'b000;
reg [2:0] znDS0_sync = 3'b000;
reg [1:0] znRST_sync = 2'b11;
reg [4:0] zREAD_sync = 5'b00000;
reg [1:0] zDOE_sync = 2'b00;
reg [1:0] zE7M_sync = 2'b00;
reg [2:0] znCFGIN_sync = 3'b000;

reg [23:0] last_addr = 0;
reg [23:0] last_read_addr = 0;
reg [15:0] last_data = 0;
reg [15:0] last_read_data = 0;

// 8 bit palette regs
reg [7:0] palette_r [0:255];
reg [7:0] palette_g [0:255];
reg [7:0] palette_b [0:255];

// sprites, currently disabled
/*reg [15:0] sprite_a1 [0:127];
reg [15:0] sprite_a2 [0:127];
reg [10:0] sprite_ax = 0;
reg [10:0] sprite_ay = 0;
reg [10:0] sprite_ax2 = 15;
reg [10:0] sprite_ay2 = 15;
reg [7:0] sprite_ptr  = 0;
reg [4:0] sprite_bit = 15;
reg [1:0] sprite_pidx = 0;
reg [7:0] sprite_palette_r [0:3];
reg [7:0] sprite_palette_g [0:3];
reg [7:0] sprite_palette_b [0:3];*/

// 0 == 8 bit
// 1 == 16 bit
// 2 == 32 bit
reg [2:0] colormode = 3;
reg [1:0] scalemode = 0;
reg [1:0] counter_scale = 0;

reg [15:0] REVISION = 'h0002;

// memory map
parameter reg_size = 32'h001000;
parameter autoconf_low  = 24'he80000;
parameter autoconf_high = 24'he80080;
reg [31:0] z3_ram_low = 32'h48000000; 
parameter z3_ram_size = 32'h02000000;
reg [31:0] z3_ram_high = 32'h48000000 + z3_ram_size-'h10000-4;
reg [31:0] z3_reg_low  = 32'h48000000 + z3_ram_size-'h10000;
reg [31:0] z3_reg_high = 32'h48000000 + z3_ram_size-'h10000 + reg_size;

reg [31:0] ram_low = 32'h600000;
parameter ram_size = 32'h400000;
reg [31:0] ram_high = 32'h9f0000;
reg [31:0] reg_low  = 32'h9f0000;
reg [31:0] reg_high = 32'h9f1000;


reg [7:0] read_counter = 0;
reg [7:0] dataout_time = 'h02;

reg [9:0] margin_x = 8;
reg [10:0] safe_x1 = 0;
reg [10:0] safe_x2 = 'h60;

// blitter registers
reg [11:0] blitter_x1 = 0;     // 20
reg [11:0] blitter_y1 = 0;     // 22
reg [11:0] blitter_x2 = 1279;  // 24
reg [11:0] blitter_y2 = 719;   // 26
reg [11:0] blitter_x3 = 0; // 2c
reg [11:0] blitter_y3 = 0; // 2e
reg [11:0] blitter_x4 = 'h100; // 30
reg [11:0] blitter_y4 = 'h100; // 32
reg [15:0] blitter_rgb = 'h0008; // 28
reg [15:0] blitter_copy_rgb = 'h0000;
reg [15:0] blitter_rgb32 [0:1];
reg blitter_rgb32_t = 1;
reg [2:0]  blitter_enable = 0; // 2a
reg [23:0] blitter_base = 0;
reg [23:0] blitter_ptr = 0;
reg [23:0] blitter_ptr2 = 0;
reg [11:0] blitter_curx = 0;
reg [11:0] blitter_cury = 0;
reg [11:0] blitter_curx2 = 0;
reg [11:0] blitter_cury2 = 0;

reg write_stall = 0;

// video capture regs (currently disabled)
/*reg capture_mode = 0;
reg [13:0] capture_x = 0;
reg [13:0] capture_y = 0;
reg [23:0] capture_ptr = 0;
reg [5:0] capture_subx = 0;
reg [5:0] capture_freq = 'h0a;
reg [7:0] capture_prex = 0;
reg [7:0] capture_prey = 0;
reg [7:0] capture_porch = 'h80;
reg [9:0] capture_shift = 512;
reg [9:0] hs_sync = 0;
reg [9:0] vs_sync = 0;
reg [7:0] vs_sync_count = 0;
reg [2:0] cap_state = 0;*/
/*reg [17:0] capture_rgb = 0;
reg [17:0] capture_rgb1 = 0;
reg [17:0] capture_rgb2 = 0;
reg [17:0] capture_rgb3 = 0;
reg [17:0] capture_rgb4 = 0;
reg [18:0] capture_rgbavg = 0;*/

// main FSM
parameter RESET = 0;
parameter Z2_CONFIGURING = 1;
parameter Z2_IDLE = 2;
parameter WAIT_READ = 3;
parameter WAIT_WRITE = 4;
parameter WAIT_WRITE2 = 6;
parameter WAIT_READ2 = 7;
parameter WAIT_READ3 = 25;

parameter CONFIGURED = 8;
parameter PAUSE = 9;

parameter Z3_IDLE = 10;
parameter Z3_WRITE_UPPER = 11;
parameter Z3_WRITE_LOWER = 12;
parameter Z3_READ_UPPER = 13;
parameter Z3_READ_LOWER = 14;
parameter Z3_READ_DELAY = 15;
parameter Z3_ENDCYCLE = 16;
parameter Z3_DTACK = 17;
parameter Z3_CONFIGURING = 18;

parameter WAIT_REGWRITE = 19;
parameter REGWRITE = 20;
parameter REGREAD = 21;
parameter REGREAD_POST = 24;

parameter RESET_DVID = 22;
parameter Z2_WARMUP = 23;
parameter Z2_PRE_CONFIGURED = 26;
parameter Z2_PRE_CONFIGURED2 = 27;

reg [6:0] zorro_state = RESET;
reg zorro_read = 0;
reg zorro_write = 0;

reg datastrobe_synced = 0;
reg zaddr_in_ram = 0;
reg zaddr_in_reg = 0;
reg zaddr_autoconfig = 0;

reg z_reset = 0;
reg z3addr_in_ram = 0;
reg z3addr_in_reg = 0;
reg z3addr_autoconfig = 0;

reg [15:0] zaddr_regpart = 0;
//reg [15:0] z3addr_rom = 0;

`ifdef ANALYZER
// logic analyzer
reg rec_enable = 0;
reg [9:0] rec_idx;
reg rec_zreadraw [0:255];
reg rec_zread [0:255];
reg rec_zwrite [0:255];
reg rec_zas0 [0:255];
reg rec_zas1 [0:255];
reg rec_zaddr_in_ram [0:255];
reg rec_state [0:255];
reg rec_statew [0:255];
reg rec_ready [0:255];
reg [3:0] rec_zaddr [0:255];
`endif

reg row_fetched = 0;

always @(posedge z_sample_clk) begin
  znUDS_sync  <= {znUDS_sync[1:0],znUDS};
  znLDS_sync  <= {znLDS_sync[1:0],znLDS};
  znDS1_sync  <= {znDS1_sync[1:0],znDS1};
  znDS0_sync  <= {znDS0_sync[1:0],znDS0};
  znAS_sync   <= {znAS_sync[3:0],znAS};
  zREAD_sync  <= {zREAD_sync[3:0],zREAD};
  zDOE_sync   <= {zDOE_sync[0],zDOE};
  zE7M_sync   <= {zE7M_sync[0],zE7M};
  znRST_sync  <= {znRST_sync[0],znRST};
  znCFGIN_sync  <= {znCFGIN_sync[1:0],znCFGIN};
  znFCS_sync <= {znFCS_sync[1:0],znFCS};
  
  z2_addr_valid <= (znAS_sync == 5'b00000);
  
  data_in <= zD;
  data_in_z3_low16 <= zA[22:7]; // FIXME why sample this twice?
  zdata_in_sync <= data_in;
  
  zorro_read  <= (zREAD_sync[2:0]==3'b111)?1'b1:1'b0; //(zREAD_sync[1] & zREAD_sync[0]);
  zorro_write <= (zREAD_sync[1:0]==2'b00)?1'b1:1'b0; //(!zREAD_sync[1] & !zREAD_sync[0]);
  
  if (znUDS_sync[1]==0 || znLDS_sync[1]==0 || znDS1_sync[1]==0 || znDS0_sync[1]==0) begin
    z3_din_high_s2 <= zD;
    z3_din_low_s2  <= zA[22:7];
  end
  
  //if (znAS_sync[1]==1 && znAS_sync[0]==0) begin
  zaddr <= {zA[22:0],1'b0};
  //end
  zaddr_sync  <= zaddr;
  zaddr_sync2 <= zaddr_sync;
  
  z2_mapped_addr <= ((zaddr_sync-ram_low)>>1);
  
  z3addr2 <= {zD[15:8],zA[22:1],2'b00};
    
  // sample z3addr on falling edge of /FCS
  if (znFCS_sync[1]==1 && znFCS_sync[0]==0) begin
    z3addr <= z3addr2;
  end
  z3_mapped_addr <= ((z3addr)&'h01ffffff)>>1;
  
  datastrobe_synced <= ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) 
                        && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0)))?1'b1:1'b0;
  
  // zaddr_sync==zaddr && 
  // zaddr_sync==zaddr_sync2 && 
  zaddr_in_ram <= (zaddr_sync==zaddr_sync2 && zaddr_sync2>=ram_low && zaddr_sync2<ram_high);
  zaddr_in_reg <= (zaddr_sync==zaddr_sync2 && zaddr_sync2>=reg_low && zaddr_sync2<reg_high);
  if (znAS_sync[1]==0 && zaddr_sync2>=autoconf_low && zaddr_sync2<autoconf_high)
    zaddr_autoconfig <= 1'b1;
  else
    zaddr_autoconfig <= 1'b0;
    
  //z3addr_rom <= z3addr[15:0];
  z_reset <= (!znRST_sync[1]); //(z3addr=='hff000000 && znCFGIN_sync[2]==0 && znFCS_sync[2]==0);
  
  z3addr_in_ram <= (z3addr >= z3_ram_low) && (z3addr < z3_ram_high);
  z3addr_in_reg <= (z3addr >= z3_reg_low) && (z3addr < z3_reg_high);
  z3addr_autoconfig <= (z3addr[31:16]=='hff00);
end

// ram arbiter
reg zorro_ram_read_request = 0;
reg zorro_ram_read_done = 1;
reg zorro_ram_write_request = 0;
reg zorro_ram_write_done = 1;
reg [23:0] zorro_ram_read_addr;
reg [15:0] zorro_ram_read_data;
reg [1:0] zorro_ram_read_bytes;
reg [23:0] zorro_ram_write_addr;
reg [15:0] zorro_ram_write_data;
reg [1:0] zorro_ram_write_bytes;

reg [4:0] ram_arbiter_state = 0;

parameter RAM_READY = 0;
parameter RAM_READY2 = 1;
parameter RAM_FETCHING_ROW8 = 2;
parameter RAM_ROW_FETCHED = 4;
parameter RAM_READING_ZORRO_PRE = 5;
parameter RAM_WRITING_ZORRO = 6;
parameter RAM_BURST_OFF = 7;
parameter RAM_BURST_ON = 8;
parameter RAM_READING_BLIT = 9;
parameter RAM_REFRESH = 10;
parameter RAM_READING_ZORRO = 11;
parameter RAM_REFRESH_PRE = 12;
parameter RAM_WRITING_ZORRO_PRE = 13;

reg [11:0] need_row_fetch_y = 0;
reg [11:0] fetch_line_y = 0;
reg [2:0] linescalecount = 0;

reg blitter_dirx = 0;
reg blitter_diry = 0;

reg [4:0] dtack_time = 0;
reg [15:0] warmup_counter = 0; // 2 seconds @ 150mhz
reg [5:0] dvid_reset_counter = 0;
reg z2_addr_valid = 0;

// =================================================================================
// ZORRO MACHINE

always @(posedge z_sample_clk) begin
      
  /*if (rec_enable) begin
    if (rec_idx==1023) begin
      rec_enable <= 0;
      rec_idx <= 0;
    end else begin
      rec_idx <= rec_idx+1;
      rec_zreadraw[rec_idx>>2] <= zREAD;
      rec_zread[rec_idx>>2] <= zorro_read;
      rec_zwrite[rec_idx>>2] <= zorro_write;
      rec_zas0[rec_idx>>2] <= znAS_sync[0];
      rec_zas1[rec_idx>>2] <= znAS_sync[1];
      rec_zaddr_in_ram[rec_idx>>2] <= zaddr_in_ram;
      rec_state[rec_idx>>2] <= ((zorro_state==WAIT_READ3)||(zorro_state==WAIT_READ2)||(zorro_state==WAIT_READ))?1'b1:1'b0;
      rec_statew[rec_idx>>2] <= ((zorro_state==WAIT_WRITE2)||(zorro_state==WAIT_WRITE))?1'b1:1'b0;
      rec_ready[rec_idx>>2] <= z_ready;
      ///rec_zaddr[rec_idx] <= zaddr;
    end
  end*/
  
  if (znCFGIN_sync[1]==1 || z_reset) begin
    zorro_state <= RESET;
  end
  
  case (zorro_state)
    RESET: begin
      vga_clk_sel  <= 0;
      screen_w     <= 1280;
      h_rez        <= 1280;
      h_sync_start <= 1280+72;
      h_sync_end   <= 1280+80;
      h_max        <= 1647;
      screen_h     <= 720;
      v_rez        <= 720;
      v_sync_start <= 720+3;
      v_sync_end   <= 720+8;
      v_max        <= 749;
      
      z_confout <= 0;
      z3_confdone <= 0;
      
      scalemode <= 0;
      colormode <= 1;
      dataout_enable <= 0;
      dataout <= 0;
      slaven <= 0;
      z_ready <= 1; // clear XRDY (cpu wait)
      zorro_ram_read_done <= 1;
      blitter_enable <= 0;
      warmup_counter <= 0;
      sdram_reset <= 1;
      
      blitter_x1 <= 0;
      blitter_y1 <= 0; 
      blitter_x2 <= 1279;
      blitter_y2 <= 719;
      blitter_ptr <= 0;
      
      ram_low   <= 'h600000;
      ram_high  <= 'h600000 + ram_size-4;
      reg_low   <= 'h600000 + ram_size;
      reg_high  <= 'h600000 + ram_size + reg_size;
      
      if (clock_locked && znRST_sync == 2'b11)
        zorro_state <= PAUSE;
    end
    
    PAUSE: begin
      // poor man's z3sense
      if (zaddr_autoconfig) begin
        ZORRO3 <= 0;
        zorro_state <= Z2_CONFIGURING;
      end else if (z3addr_autoconfig) begin
        ZORRO3 <= 1;
        zorro_state <= Z3_CONFIGURING;
      end
    end
    
    Z3_CONFIGURING: begin
      if (znCFGIN_sync[2]==0 && z3addr_autoconfig && znFCS_sync[1]==0) begin
        if (zorro_read) begin
          // autoconfig ROM
          dataout_enable <= 1;
          dataout_z3 <= 1;
          data_z3_low16 <= 'hffff;
          slaven <= 1;
          dtack_time <= 0;
          zorro_state <= Z3_DTACK;
          
          case (z3addr[15:0])
            'h0000: data_z3_hi16 <= 'b1000_1111_1111_1111; // zorro 3 (10), no pool link (0), no autoboot (0)
            'h0100: data_z3_hi16 <= 'b0001_1111_1111_1111; // next board unrelated (0), 32mb
            
            'h0004: data_z3_hi16 <= 'b1111_1111_1111_1111; // product number
            'h0104: data_z3_hi16 <= 'b1110_1111_1111_1111; // (1)
            
            'h0008: data_z3_hi16 <= 'b0000_1111_1111_1111; // flags inverted 0111 io,shutup,extension,reserved(1)
            'h0108: data_z3_hi16 <= 'b1111_1111_1111_1111; // inverted zero
            
            'h000c: data_z3_hi16 <= 'b1111_1111_1111_1111; // reserved?
            'h010c: data_z3_hi16 <= 'b1111_1111_1111_1111; // 
            
            'h0010: data_z3_hi16 <= 'b1001_1111_1111_1111; // manufacturer high byte inverted
            'h0110: data_z3_hi16 <= 'b0010_1111_1111_1111; // 
            'h0014: data_z3_hi16 <= 'b1001_1111_1111_1111; // manufacturer low byte
            'h0114: data_z3_hi16 <= 'b0001_1111_1111_1111;
            
            'h0018: data_z3_hi16 <= 'b1111_1111_1111_1111; // serial 01 01 01 01
            'h0118: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h001c: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h011c: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h0020: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h0120: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h0024: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h0124: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            
            //'h000040: data_z3_hi16 <= 'b0000_0000_0000_0000; // interrupts (not inverted)
            //'h000042: data_z3_hi16 <= 'b0000_0000_0000_0000; //
           
            default: data_z3_hi16 <= 'b1111_1111_1111_1111;
          endcase
        end else begin
          // write to autoconfig register
          slaven <= 1;
          if (((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
            dtack_time <= 0;
            zorro_state <= Z3_DTACK;
            casex (z3addr[15:0])
              'hXX44: begin
                z3_ram_low[31:16] <= data_in;
                z3_confdone <= 1;
              end
              'hXX48: begin
              end
              'hXX4c: begin
                // shutup
                z3_confdone <= 1;
              end
            endcase
          end
        end
      end else begin
        // no address match
        dataout_z3 <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        dtack <= 0;
      end
    end
    
    Z3_DTACK: begin
      if (znFCS_sync[2]==1) begin
        dtack <= 0;
        dataout_z3 <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        dtack_time <= 0;
        if (z3_confdone) begin
          zorro_state <= CONFIGURED;
          ram_high  <= z3_ram_low + z3_ram_size-'h10000-4;
          reg_low   <= z3_ram_low + z3_ram_size-'h10000;
          reg_high  <= z3_ram_low + z3_ram_size-'h10000 + reg_size;
        end else
          zorro_state <= Z3_CONFIGURING;
      end else begin
        if (dtack_time < 2)
          dtack_time <= dtack_time + 1'b1;
        else
          dtack <= 1;
      end
    end
    
    Z2_CONFIGURING: begin
      // CHECK
      if (zaddr_autoconfig && !znCFGIN_sync[2]) begin
        if (zorro_read) begin
          // read iospace 'he80000 (Autoconfig ROM)
          dataout_enable <= 1;
          dataout <= 1;
          slaven <= 1;
          
          case (zaddr_sync2[7:0])
            8'h00: data <= 'b1100_1111_1111_1111; // zorro 2
            8'h02: data <= 'b0111_1111_1111_1111; // next board unrelated (0), 4mb
            
            8'h04: data <= 'b1111_1111_1111_1111; // product number
            8'h06: data <= 'b1110_1111_1111_1111; // (1)
            
            8'h08: data <= 'b0011_1111_1111_1111; // flags inverted 0011
            8'h0a: data <= 'b1111_1111_1111_1111; // inverted zero
            
            8'h10: data <= 'b1001_1111_1111_1111; // manufacturer high byte inverted (02)
            8'h12: data <= 'b0010_1111_1111_1111; // 
            8'h14: data <= 'b1001_1111_1111_1111; // manufacturer low byte (9a)
            8'h16: data <= 'b0001_1111_1111_1111;
            
            8'h18: data <= 'b1111_1111_1111_1111; // serial 01 01 01 01
            8'h1a: data <= 'b1110_1111_1111_1111; //
            8'h1c: data <= 'b1111_1111_1111_1111; //
            8'h1e: data <= 'b1110_1111_1111_1111; //
            8'h20: data <= 'b1111_1111_1111_1111; //
            8'h22: data <= 'b1110_1111_1111_1111; //
            8'h24: data <= 'b1111_1111_1111_1111; //
            8'h26: data <= 'b1110_1111_1111_1111; //
            
            //'h000040: data <= 'b0000_0000_0000_0000; // interrupts (not inverted)
            //'h000042: data <= 'b0000_0000_0000_0000; //
           
            default: data <= 'b1111_1111_1111_1111;
          endcase
        end else begin
          // write to autoconfig register
          if (datastrobe_synced) begin
            case (zaddr_sync2[7:0])
              8'h48: begin
                ram_low[31:24] <= 8'h0;
                ram_low[23:20] <= zdata_in_sync[15:12];
                ram_low[15:0] <= 16'h0;
                zorro_state <= Z2_PRE_CONFIGURED; // configured
              end
              8'h4a: begin
                ram_low[31:24] <= 8'h0;
                ram_low[19:16] <= zdata_in_sync[15:12];
                ram_low[15:0] <= 16'h0;
              end
              
              8'h4c: begin 
                zorro_state <= Z2_PRE_CONFIGURED; // configured, shut up
              end
            endcase
          end
        end
      end else begin
        // no address match
        dataout <= 0;
        dataout_enable <= 0;
        slaven <= 0;
      end
    end
    
    Z2_PRE_CONFIGURED: begin
      if (znAS_sync[2]==1) begin
        z_confout<=1;
        zorro_state <= CONFIGURED;
      end
    end
    
    /*Z2_PRE_CONFIGURED2: begin
      if (znCFGIN_sync[2:0]=='b111) begin
        zorro_state <= Z2_IDLE;
      end
    end*/
    
    CONFIGURED: begin
      scalemode <= 0;
      colormode <= 1;
      blitter_base <= 0;
      pan_ptr <= 0;
      burst_enabled <= 1;
      margin_x <= 7;
      row_pitch <= 2048;
      row_pitch_shift <= 11;
      
      blitter_enable <= 1;
      blitter_rgb <= 'h1111;

      ram_high  <= ram_low + ram_size-'h10000-4;
      reg_low   <= ram_low + ram_size-'h10000;
      reg_high  <= ram_low + ram_size-'h10000 + reg_size;
      
      z3_ram_high  <= z3_ram_low + z3_ram_size-'h10000-4;
      z3_reg_low   <= z3_ram_low + z3_ram_size-'h10000;
      z3_reg_high  <= z3_ram_low + z3_ram_size-'h10000 + reg_size;
      
      z_confout <= 1;
      
      sdram_reset <= 0;
      if (ZORRO3) begin
        zorro_state <= Z3_IDLE;
      end else begin
        zorro_state <= Z2_IDLE;
      end
    end
  
    // ----------------------------------------------------------------------------------
    Z2_IDLE: begin
      if (dvid_reset) begin
        dvid_reset_counter <= 2;
        zorro_state <= RESET_DVID;
      end else
      if (z2_addr_valid) begin
        if (zorro_read && zaddr_in_ram) begin
          /*if (!rec_enable) begin 
            rec_enable <= 1;
            rec_idx <= 0;
          end*/
          
          // read RAM
          // request ram access from arbiter
          last_addr <= ((zaddr_sync2-ram_low)>>1);
          data <= 'hffff;
          read_counter <= 0;
          
          slaven <= 1;
          dataout_enable <= 1;
          dataout <= 1;
          
          zorro_state <= WAIT_READ3;
          
        end else if (zorro_write && zaddr_in_ram) begin
          // write RAM          
          last_addr <= ((zaddr_sync2-ram_low)>>1); // z2_mapped_addr
          zorro_state <= WAIT_WRITE;
          
        end else if (zorro_write && zaddr_in_reg) begin
          // write to register
          zaddr_regpart <= z2_mapped_addr[15:0];
          zorro_state <= WAIT_REGWRITE;
          
        end else if (zorro_read && zaddr_in_reg) begin
          // read from registers
          
          dataout_enable <= 1;
          dataout <= 1;
          slaven <= 1;
          
          case (zaddr_sync2[7:0])
            //'h00: data <= REVISION;
            'h20: data <= blitter_x1;
            'h22: data <= blitter_y1;
            'h24: data <= blitter_x2;
            'h26: data <= blitter_y2;
            'h28: data <= blitter_rgb;
            'h2a: data <= blitter_enable;
            
            'h60: data <= {sd_busy,8'h00};
            'h62: data <= {sd_read,8'h00};
            'h64: data <= {sd_write,8'h00};
            'h66: data <= {sd_handshake_out,8'h00};
            'h68: data <= sd_addr_in[31:16];
            'h6a: data <= sd_addr_in[15:0];
            'h6c: data <= {sd_data_in,8'h00};
            'h6e: data <= {sd_data_out,8'h00};
            'h70: data <= sd_error;
            //'h72: data <= sd_clkdiv;
            
            default: data <= REVISION; //'h0000;
          endcase
        end        
      end else begin
        dataout <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        write_stall <= 0;
        z_ready <= 1; // clear XRDY (cpu wait)
      end
    end
    
    WAIT_REGWRITE: begin
      if (datastrobe_synced) begin
        regdata_in <= zdata_in_sync;
        zaddr_regpart <= zaddr_sync2[15:0];
        zorro_state <= REGWRITE;
      end
    end
    
    // ----------------------------------------------------------------------------------
    WAIT_READ3: begin
      z_ready <= 0;
      if (!zorro_ram_read_request) begin
        zorro_ram_read_addr <= last_addr;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
        zorro_state <= WAIT_READ2;
      end
    end
    
    WAIT_READ2: begin
      /*if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        // ram too slow TODO: report this
        zorro_ram_read_request <= 0;
        zorro_state <= Z2_IDLE;
        z_ready <= 1;
      end else */
      
      if (zorro_ram_read_done) begin
        data <= zorro_ram_read_data;
        read_counter <= read_counter + 1;
        zorro_ram_read_request <= 0;
        
        if (read_counter >= dataout_time) begin
          zorro_state <= WAIT_READ;
        end
      end
    end
  
    // ----------------------------------------------------------------------------------
    WAIT_READ: begin
      //data <= zorro_ram_read_data;
      z_ready <= 1;
      if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        zorro_state <= Z2_IDLE;
      end
    end
   
    // ----------------------------------------------------------------------------------
    WAIT_WRITE:
      if (!zorro_ram_write_request) begin
        z_ready <= 1;
        write_stall <= 0;
        if (datastrobe_synced) begin // && zdata_in_sync==data_in
          zorro_ram_write_addr <= last_addr;
          zorro_ram_write_bytes <= {~znUDS_sync[2],~znLDS_sync[2]};
          zorro_ram_write_data <= zdata_in_sync;
          zorro_ram_write_request <= 1;
          
          zorro_state <= WAIT_WRITE2;
        end
      end else begin
        z_ready <= 0;
        write_stall <= 1;
      end
    
    // ----------------------------------------------------------------------------------
    WAIT_WRITE2: begin
      z_ready <= 1;
      if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        zorro_state <= Z2_IDLE;
      end
    end
    
    RESET_DVID: begin
      /*ram_arbiter_state <= RAM_READY;
      zorro_ram_write_request <= 0;
      zorro_ram_read_request <= 0;
      zorro_ram_read_done <= 1;
      fetch_line_y <= 0;
      fetch_x <= 0;
      row_fetched <= 1;*/
      
      if (dvid_reset_counter==0) begin
        dvid_reset <= 0;
        if (ZORRO3)
          zorro_state <= Z3_IDLE;
        else
          zorro_state <= Z2_IDLE;
      end else
        dvid_reset_counter <= dvid_reset_counter - 1'b1;
    end
    
    // ----------------------------------------------------------------------------------
    // ----------------------------------------------------------------------------------
    Z3_IDLE: begin
      if (dvid_reset) begin
        dvid_reset_counter <= 2;
        zorro_state <= RESET_DVID;
      end else
      if (znFCS_sync[2]==0) begin
        // falling edge of /FCS
        if (z3addr_in_ram && zorro_write) begin
          slaven <= 1;
          if ((znUDS_sync[2]==0) || (znLDS_sync[2]==0) || (znDS1_sync[2]==0) || (znDS0_sync[2]==0)) begin
            zorro_state <= Z3_WRITE_UPPER;
          end
        end else if (z3addr_in_ram && zorro_read) begin
          // read from memory
          slaven <= 1;
          zorro_state <= Z3_READ_UPPER;
        end else if (zorro_write && z3addr_in_reg) begin
          // write to register
          slaven <= 1;
          if (znDS1_sync[2]==0) begin
            regdata_in <= data_in_z3_low16;
            zaddr_regpart <= (z3addr[15:0])|16'h2;
            zorro_state <= REGWRITE;
          end else if (znUDS_sync[2]==0) begin
            regdata_in <= zdata_in_sync;
            zaddr_regpart <= z3addr[15:0];
            zorro_state <= REGWRITE;
          end
        end else if (zorro_read && z3addr_in_reg) begin
          // read registers
          slaven <= 1;
          data_z3_hi16 <= 0;
          data_z3_low16 <= 0;
          
          if (znDS1_sync[2]==0 || znDS0_sync[2]==0 || znUDS_sync[2]==0 || znLDS_sync[2]==0) begin
            zaddr_regpart <= {z3addr[15:2],2'b00}; //|16'h2;
            zorro_state <= REGREAD;
          end
        end else begin
          // address not recognized
          slaven <= 0;
          //dtack <= 0;
          //dataout_enable <= 0;
          //dataout_z3 <= 0;
        end
        
      end else begin
        // not in a cycle
        slaven <= 0;
        //dtack <= 0;
        //dataout_enable <= 0;
        //dataout_z3 <= 0;
      end
    end
    
    Z3_READ_UPPER: begin
      if (!zorro_ram_read_request) begin
        z3_read_addr <= z3_mapped_addr;
        zorro_state <= Z3_READ_LOWER;
        zorro_ram_read_addr <= z3_mapped_addr[23:0];
        zorro_ram_read_bytes <= 2'b11;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
      end
    end
    
    // FIXME looks racy
    Z3_READ_LOWER: begin
      if (zorro_ram_read_done) begin
        zorro_ram_read_addr <= (z3_read_addr[23:0])|24'b1;
        zorro_ram_read_bytes <= 2'b11;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
        z3_read_data <= zorro_ram_read_data;
        zorro_state <= Z3_READ_DELAY;
      end
    end
    
    Z3_READ_DELAY: begin
      if (zorro_ram_read_done) begin
        data_z3_hi16 <= z3_read_data;
        data_z3_low16 <= zorro_ram_read_data;
        dataout_enable <= 1;
        dataout_z3 <= 1;
        zorro_ram_read_done <= 0;
        zorro_state <= Z3_ENDCYCLE;
      end
    end
    
    Z3_WRITE_UPPER: begin
      // wait for free memory bus
      if ((znUDS_sync[2]==0) || (znLDS_sync[2]==0)) begin
        if (!zorro_ram_write_request) begin
          zorro_ram_write_addr <= z3_mapped_addr[23:0];
          zorro_ram_write_bytes <= ~{znUDS_sync[2],znLDS_sync[2]};
          zorro_ram_write_data <= z3_din_high_s2;
          zorro_ram_write_request <= 1;
          zorro_state <= Z3_WRITE_LOWER;
        end
      end else begin
        // only lower bytes shall be written
        zorro_state <= Z3_WRITE_LOWER;
      end
    end
    
    Z3_WRITE_LOWER: begin
      if ((znDS1_sync[2]==0) || (znDS0_sync[2]==0)) begin
        if (!zorro_ram_write_request) begin
          zorro_ram_write_addr <= (z3_mapped_addr[23:0])|1'b1;
          zorro_ram_write_bytes <= ~{znDS1_sync[2],znDS0_sync[2]};
          zorro_ram_write_data <= z3_din_low_s2; // low!
          zorro_ram_write_request <= 1;
          
          zorro_state <= Z3_ENDCYCLE;
        end
      end else begin
        zorro_state <= Z3_ENDCYCLE;
      end
    end
    
    Z3_ENDCYCLE: begin
      if (znFCS_sync[2]==1) begin
        dtack <= 0;
        slaven <= 0;
        dataout_enable <= 0;
        dataout_z3 <= 0;
        zorro_state <= Z3_IDLE;
      end else
        dtack <= 1;
    end
    
    REGREAD_POST: begin
      data_z3_hi16 <= z3_regread_hi;
      data_z3_low16 <= z3_regread_lo;
      zorro_state <= Z3_ENDCYCLE;
    end
    
    REGREAD: begin
      dataout_enable <= 1;
      dataout_z3 <= 1;
      zorro_state <= REGREAD_POST;
      
      case (zaddr_regpart)
        /*'h00: begin z3_regread_hi <= REVISION;
              z3_regread_lo <= 0; end*/
        'h20: begin z3_regread_hi <= blitter_x1;
              z3_regread_lo <= blitter_y1; end // 'h22
              
        'h24: begin z3_regread_hi <= blitter_x2;
              z3_regread_lo <= blitter_y2; end // 'h26
              
        'h28: begin z3_regread_hi <= blitter_rgb;
              z3_regread_lo <= blitter_enable; end // 'h2a
        
        'h60: begin z3_regread_hi <= {sd_busy,8'h00};
              z3_regread_lo <= {sd_read,8'h00}; end // 'h62
        'h64: begin z3_regread_hi <= {sd_write,8'h00};
              z3_regread_lo <= {sd_handshake_out,8'h00}; end // 'h66
        'h68: begin z3_regread_hi <= sd_addr_in[31:16];
              z3_regread_lo <= sd_addr_in[15:0]; end // 'h6a
        'h6c: begin z3_regread_hi <= {sd_data_in,8'h00};
              z3_regread_lo <= {sd_data_out,8'h00}; end // 'h6e
        
        'h70: begin z3_regread_hi <= sd_error; z3_regread_lo <= 0; end
        /*'h72: data_z3_low16 <= sd_clkdiv;*/
        
        'h80: begin z3_regread_hi <= ram_arbiter_state; z3_regread_lo <= zorro_state; end
        'h84: begin z3_regread_hi <= counter_x; z3_regread_lo <= counter_y; end
        'h88: begin z3_regread_hi <= h_max; z3_regread_lo <= v_max; end
        'h8c: begin z3_regread_hi <= fetch_x; z3_regread_lo <= 0; end
        'h90: begin z3_regread_hi <= fetch_y[23:16]; z3_regread_lo <= fetch_y[15:0]; end
        'h94: begin z3_regread_hi <= data_out_ready; z3_regread_lo <= ram_enable; end
        'h98: begin z3_regread_hi <= ram_write; z3_regread_lo <= 0; end
        
        default: begin
          z3_regread_hi <= REVISION; //'h0000; 
          z3_regread_lo <= 'h0000;
        end
      endcase
    end
    
    REGWRITE: begin
      if (ZORRO3) begin
        zorro_state <= Z3_ENDCYCLE;
      end else
        zorro_state <= Z2_IDLE;
      
      if (zaddr_regpart>='h600) begin
        palette_r[zaddr_regpart[8:1]] <= regdata_in[7:0];
      end else if (zaddr_regpart>='h400) begin
        palette_g[zaddr_regpart[8:1]] <= regdata_in[7:0];
      end else if (zaddr_regpart>='h200) begin
        palette_b[zaddr_regpart[8:1]] <= regdata_in[7:0];
      end else
      case (zaddr_regpart)
        'h02: screen_w <= regdata_in[11:0];
        'h04: scalemode <= regdata_in[1:0];
        'h06: begin
          screen_w <= regdata_in[11:0];
          h_rez    <= regdata_in[11:0];
        end
        'h08: begin
          screen_h <= regdata_in[11:0];
          v_rez    <= regdata_in[11:0];
        end
        'h82: refresh_time <= regdata_in[15:0];
        
        'h70: h_sync_start <= regdata_in[11:0];
        'h72: h_sync_end <= regdata_in[11:0];
        'h74: h_max <= regdata_in[11:0];
        'h76: v_sync_start <= regdata_in[11:0];
        'h78: v_sync_end <= regdata_in[11:0];
        'h7a: v_max <= regdata_in[11:0];
        'h7c: begin 
          vga_clk_sel <= regdata_in[1:0];
          dvid_reset <= 1;
        end
        
        //'h0a: dataout_time <= regdata_in[7:0];
        'h0c: margin_x <= regdata_in[9:0];
        'h10: preheat_x <= regdata_in[4:0];
        //'h12: safe_x1 <= regdata_in[10:0];
        'h14: safe_x2 <= regdata_in[10:0];
        /*'h16: glitchx2_reg <= regdata_in[10:0];
        'h18: ram_burst_col <= regdata_in[8:0];*/
        'h1a: fetch_preroll <= regdata_in[10:0];
        
        // blitter regs
        'h1c: blitter_base[23:16] <= regdata_in[7:0];
        'h1e: blitter_base[15:0]  <= regdata_in;
        'h20: blitter_x1 <= regdata_in[11:0];
        'h22: blitter_y1 <= regdata_in[11:0];
        'h24: blitter_x2 <= regdata_in[11:0];
        'h26: blitter_y2 <= regdata_in[11:0];
        'h28: blitter_rgb <= regdata_in[15:0];
        'h2a: begin
          blitter_enable <= regdata_in[3:0];
          
          blitter_curx <= blitter_x1;
          blitter_cury <= blitter_y1;
          blitter_curx2 <= blitter_x3;
          blitter_cury2 <= blitter_y3;
          
          blitter_dirx <= (blitter_x3>blitter_x4)?1'b1:1'b0;
          blitter_diry <= (blitter_y3>blitter_y4)?1'b1:1'b0;
          
          blitter_ptr <= blitter_base + (blitter_y1 << row_pitch_shift);
          blitter_ptr2 <= blitter_base + (blitter_y3 << row_pitch_shift);
          blitter_rgb32_t <= 1;
        end
        'h2c: blitter_x3 <= regdata_in[11:0];
        'h2e: blitter_y3 <= regdata_in[11:0];
        'h30: blitter_x4 <= regdata_in[11:0];
        'h32: blitter_y4 <= regdata_in[11:0];
        'h34: blitter_rgb32[0] <= regdata_in[15:0];
        'h36: blitter_rgb32[1] <= regdata_in[15:0];
        
        'h38: pan_ptr[23:16] <= regdata_in[7:0];
        'h3a: pan_ptr[15:0]  <= regdata_in;
        
        /*'h40: sprite_ax <= regdata_in[10:0];
        'h42: sprite_ay <= regdata_in[10:0];
        'h44: sprite_ax2 <= regdata_in[10:0];
        'h46: sprite_ay2 <= regdata_in[10:0];*/
        
        'h48: colormode <= regdata_in[2:0];
        
        //'h50: capture_mode <= regdata_in[0];
        //'h52: capture_freq <= regdata_in[5:0];
        //'h54: capture_porch <= regdata_in[7:0];
        //'h56: capture_shift <= regdata_in[9:0];
        
        'h58: row_pitch <= regdata_in;
        //'h5a: burst_enabled <= regdata_in[0];
        'h5c: row_pitch_shift <= regdata_in[4:0];
        
        // sd card regs
        'h60: sd_reset <= regdata_in[8];
        'h62: sd_read <= regdata_in[8];
        'h64: sd_write <= regdata_in[8];
        'h66: sd_handshake_in <= regdata_in[8];
        'h68: sd_addr_in[31:16] <= regdata_in[15:0];
        'h6a: sd_addr_in[15:0] <= regdata_in[15:0];
        'h6c: sd_data_in <= regdata_in[15:8];
        
        'h80: ram_arbiter_state <= regdata_in[4:0];
      endcase
    end
    
    default:
      // shouldn't happen
      zorro_state <= CONFIGURED;

  endcase

// =================================================================================
// RAM ARBITER

  case (ram_arbiter_state)
    RAM_READY: begin
      ram_enable <= 1;
      //ram_write <= 0;
      ram_arbiter_state <= RAM_READY2;
      fetch_y <= pan_ptr + (fetch_line_y << row_pitch_shift);
    end
    
    RAM_READY2: begin
      // start fetching a row
      ram_addr  <= fetch_y+glitchx2_reg;
      ram_write <= 0;
      ram_byte_enable <= 'b11;
      //ram_enable <= 1;
      fetch_x <= 0;
      fetch_x2 <= glitchx2_reg;
      
      if (row_fetched) begin
        ram_burst <= 0;
        ram_arbiter_state <= RAM_BURST_OFF;
      end else begin
        ram_burst <= 1;
        ram_arbiter_state <= RAM_BURST_ON;
      end
    end
    
    RAM_BURST_ON: begin
      //ram_enable <= 1;
      //ram_write <= 0;
      if (cmd_ready) ram_arbiter_state <= RAM_FETCHING_ROW8;
    end
    
    RAM_FETCHING_ROW8: begin
      //ram_enable <= 1;
      //ram_write <= 0;
      if ((fetch_x >= (screen_w + margin_x))) begin
        row_fetched <= 1; // row completely fetched
        ram_burst <= 0;
        ram_arbiter_state <= RAM_READY;
        
      end else if (data_out_ready) begin
        ram_enable <= 1;
        ram_write <= 0;
        ram_byte_enable <= 'b11;
        ram_addr  <= ram_addr + 1'b1; // burst incremented
      
        fetch_x <= fetch_x + 1'b1;
        fetch_x2 <= fetch_x2 + 1'b1;
        
        fetch_buffer[fetch_x] <= ram_data_out;
      end
    end
    
    RAM_BURST_OFF: begin
      ram_enable <= 0;
      if (data_out_queue_empty && cmd_ready)
        ram_arbiter_state <= RAM_ROW_FETCHED;
    end
    
    RAM_ROW_FETCHED:
      if ((need_row_fetch_y!=fetch_line_y) && (counter_x > h_max-safe_x2)) begin
        row_fetched <= 0;
        fetch_x <= 0;
        fetch_line_y <= need_row_fetch_y;
        //linescalecount <= 0;
        ram_arbiter_state <= RAM_READY;
        
      // FIXME need better solution, this causes total lockup and slowness
      end else if (counter_x > h_max-safe_x2) begin
        // do nothing if not in safe area
        
      // BLITTER ----------------------------------------------------------------
      /*end else if (blitter_enable==1 && cmd_ready) begin
        if (colormode==2) begin
          blitter_rgb <= blitter_rgb32[blitter_rgb32_t];
        end
        blitter_rgb32_t <= ~blitter_rgb32_t;
        
        // rect fill blitter
        if (blitter_curx <= blitter_x2) begin
          blitter_curx <= blitter_curx + 1'b1;
          ram_byte_enable <= 'b11;
          ram_addr    <= blitter_ptr + blitter_curx;          
          ram_data_in <= blitter_rgb;
          ram_write   <= 1;
          ram_enable  <= 1;
        end else if (blitter_cury<blitter_y2) begin
          blitter_cury <= blitter_cury + 1'b1;
          blitter_curx <= blitter_x1;
          blitter_ptr <= blitter_ptr + row_pitch;
        end else begin
          blitter_curx <= 0;
          blitter_cury <= 0;
          blitter_enable <= 0;
          //ram_enable <= 0;
        end*/
      /*end else if (blitter_enable==2 && cmd_ready) begin
        // block copy read
        if (data_out_queue_empty) begin
          ram_byte_enable <= 'b11;
          ram_addr    <= blitter_ptr2+blitter_curx2;
          ram_write   <= 0;
          ram_enable  <= 1;
          ram_arbiter_state <= RAM_READING_BLIT;
        end else 
          ram_enable <= 0;
        
      end else if (blitter_enable==4 && cmd_ready) begin
        // block copy write
        ram_addr    <= blitter_ptr+blitter_curx;
        ram_data_in <= blitter_copy_rgb;
        ram_write   <= 1;
        ram_enable  <= 1;
        ram_byte_enable <= 'b11;
        
        if (blitter_curx2 != blitter_x4) begin
          if (blitter_dirx==1) begin
            blitter_curx2 <= blitter_curx2 - 1'b1;
            blitter_curx  <= blitter_curx - 1'b1;
          end else begin
            blitter_curx2 <= blitter_curx2 + 1'b1;
            blitter_curx  <= blitter_curx + 1'b1;
          end
        end else if (blitter_cury2 == blitter_y4) begin
          // done
        end else if (blitter_diry == 0) begin
          blitter_curx <= blitter_x1;
          blitter_curx2 <= blitter_x3;
          blitter_ptr <= blitter_ptr + row_pitch;
          blitter_ptr2 <= blitter_ptr2 + row_pitch;
          blitter_cury <= blitter_cury + 1'b1;
          blitter_cury2 <= blitter_cury2 + 1'b1;
        end else begin
          blitter_curx <= blitter_x1;
          blitter_curx2 <= blitter_x3;
          blitter_ptr <= blitter_ptr - row_pitch;
          blitter_ptr2 <= blitter_ptr2 - row_pitch;
          blitter_cury <= blitter_cury - 1'b1;
          blitter_cury2 <= blitter_cury2 - 1'b1;
        end
        
        blitter_enable <= 5; // next
      end else if (blitter_enable==5) begin
        if (blitter_curx2==blitter_x4 && blitter_cury2 == blitter_y4)
          blitter_enable <= 0;
        else
          blitter_enable <= 2;
        ram_enable <= 0;
        */
      // ZORRO READ/WRITE ----------------------------------------------
      end else if (/*blitter_enable==0 &&*/ zorro_ram_read_request && cmd_ready) begin
        // process read request
        zorro_ram_read_done <= 0;
        if (data_out_queue_empty) begin
          ram_arbiter_state <= RAM_READING_ZORRO_PRE;
        end else 
          ram_enable <= 0;
      end else if (/*blitter_enable==0 &&*/ zorro_ram_write_request && cmd_ready) begin
        // process write request
        ram_arbiter_state <= RAM_WRITING_ZORRO_PRE;
      end else if (/*blitter_enable==0 &&*/ refresh_counter>refresh_time && !zorro_ram_read_request && !zorro_ram_write_request && cmd_ready) begin
        ram_arbiter_state <= RAM_REFRESH_PRE;
      end else if (blitter_enable) begin
        blitter_enable <= 0;
      end else
        refresh_counter <= refresh_counter + 1;
    
    RAM_REFRESH_PRE: begin
      if (data_out_queue_empty) begin
        ram_write <= 0;
        ram_addr <= refresh_addr;
        ram_byte_enable <= 'b11;
        refresh_addr <= refresh_addr + 512;
        ram_enable <= 1;
        ram_arbiter_state <= RAM_REFRESH;
        refresh_counter <= 0;
      end else 
        ram_enable <= 0;
    end
    
    RAM_REFRESH: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_READING_BLIT: begin
      // block copy (data ready)
      if (data_out_ready) begin
        ram_enable <= 0;
        blitter_copy_rgb <= ram_data_out;
        blitter_enable <= 4;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_READING_ZORRO_PRE: begin
      ram_write <= 0;
      ram_addr <= zorro_ram_read_addr;
      ram_byte_enable <= 'b11;
      ram_enable <= 1;
      ram_arbiter_state <= RAM_READING_ZORRO;
    end
    
    RAM_READING_ZORRO: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        zorro_ram_read_data <= ram_data_out;
        zorro_ram_read_done <= 1;
        zorro_ram_read_request <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end/* else begin // FIXME
        ram_enable <= 1;
        ram_write <= 0;
      end*/
    end
    
    RAM_WRITING_ZORRO_PRE: begin
      if (zorro_ram_write_bytes[1] && !zorro_ram_write_bytes[0])
        ram_byte_enable <= 'b10; // UDS
      else if (zorro_ram_write_bytes[0] && !zorro_ram_write_bytes[1])
        ram_byte_enable <= 'b01; // LDS
      else
        ram_byte_enable <= 'b11;
      
      ram_data_in <= zorro_ram_write_data;
      ram_addr    <= zorro_ram_write_addr;
      ram_write   <= 1;
      ram_enable  <= 1;
      
      ram_arbiter_state <= RAM_WRITING_ZORRO;
    end
    
    RAM_WRITING_ZORRO: begin
      zorro_ram_write_done <= 1;
      zorro_ram_write_request <= 0;
        
      ram_enable <= 0;
      ram_arbiter_state <= RAM_ROW_FETCHED;
    end
    
    default:
      // should also never happen
      ram_arbiter_state <= RAM_READY;
    
  endcase
end

reg[23:0] rgb = 'h000000;
reg[31:0] rgb32 = 'h00000000;
reg[11:0] counter_8x = 0;
reg counter_x_hi = 0;
reg scale_xc = 0;
reg[7:0] pidx1;
reg[7:0] pidx2;

reg display_sprite = 0;

reg [4:0] preheat_x = 0;
reg preheat = 0;

always @(posedge vga_clk) begin
  if (counter_x >= h_max-preheat_x && !preheat) begin
    counter_8x <= margin_x;
    counter_x_hi <= 0;
    counter_scale <= scalemode;
    display_x <= margin_x;
    display_x2 <= margin_x<<1'b1;
    display_x3 <= (margin_x<<1'b1)+1'b1;
    
    preheat <= 1;
  end
  
  if (counter_x >= h_max) begin
    counter_x <= 0;
    preheat <= 0;
    
    if (counter_y >= v_max) begin
      counter_y <= 0;
    end else
      counter_y <= counter_y + 1'b1;
  end else begin
    counter_x <= counter_x + 1'b1;
    display_x <= display_x + 1'b1;
  
    if (counter_x==h_max-fetch_preroll) begin
      if (counter_y<screen_h-1'b1)
        need_row_fetch_y <= (counter_y>>scalemode)+1'b1;
      else //if (counter_y==screen_h-1'b1)
        need_row_fetch_y <= 0;
    end
  end
    
  if (counter_x>=h_sync_start && counter_x<h_sync_end)
    dvi_hsync <= 1;
  else
    dvi_hsync <= 0;
    
  if (counter_y>=v_sync_start && counter_y<v_sync_end)
    dvi_vsync <= 1;
  else
    dvi_vsync <= 0;
      
  if (counter_x<h_rez && counter_y<v_rez) begin
    dvi_blank <= 0;
  end else begin
    dvi_blank <= 1;
  end
  
  if (!preheat && (dvi_blank || (counter_x>=h_rez) || (counter_y>=screen_h))) begin
    red_p   <= 0;
    green_p <= 0;
    blue_p  <= 0;
  end else if (counter_y>=590) begin
    if (counter_x<110) begin
      if (zorro_state[4]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<120) begin
      if (zorro_state[3]) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<130) begin
      if (zorro_state[2]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<140) begin
      if (zorro_state[1]) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<150) begin
      if (zorro_state[0]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<160) begin
      green_p <= 0;
    
    end else if (counter_x<170) begin
      if (ram_arbiter_state[4]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<180) begin
      if (ram_arbiter_state[3]) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<190) begin
      if (ram_arbiter_state[2]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<200) begin
      if (ram_arbiter_state[1]) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<210) begin
      if (ram_arbiter_state[0]) green_p <= 8'hff;
      else green_p <= 8'h20;
      
    /*end else if (counter_x<220) begin
      green_p <= 0;
    end else if (counter_x<230) begin
      if (cmd_ready) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<240) begin
      if (blitter_enable[0]) green_p <= 8'hff;
      else green_p <= 8'h20;
    end else if (counter_x<250) begin
      if (zorro_ram_read_request) green_p <= 8'hff;
      else green_p <= 8'h40;
    end else if (counter_x<260) begin
      if (zorro_ram_read_done) green_p <= 8'hff;
      else green_p <= 8'h40;*/
    end else begin
      green_p <= 0;
      blue_p <= 0;
    end
    
    /*if (counter_y<600) begin
      if (rec_zreadraw[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<610) begin
      if (rec_zread[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<620) begin
      if (rec_zwrite[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<630) begin
      if (rec_zas0[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<640) begin
      if (rec_zas1[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<650) begin
      if (rec_zaddr_in_ram[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else if (counter_y<660) begin
      if (rec_state[counter_x]) blue_p <= 8'hff;
      else blue_p <= 0;
    end else if (counter_y<670) begin
      if (rec_statew[counter_x]) blue_p <= 8'hff;
      else blue_p <= 0;
    end else if (counter_y<680) begin
      if (rec_ready[counter_x]) green_p <= 8'hff;
      else green_p <= 0;
    end else begin
      green_p <= 0;
      blue_p <= 0;
    end*/
    
  end else if (colormode==0) begin
    // 0: +0a +0b +1a
    // 1: +0b +1a +1b
    
    if (preheat) begin
      red_p <= 0;
      green_p <= 0;
      blue_p <= 0;
    end else if (counter_scale != scalemode) begin
      counter_scale <= counter_scale + 1'b1;
    end else if (counter_x_hi==1) begin
      red_p   <= palette_r[fetch_buffer[counter_8x][7:0]];
      green_p <= palette_g[fetch_buffer[counter_8x][7:0]];
      blue_p  <= palette_b[fetch_buffer[counter_8x][7:0]];
      counter_8x <= counter_8x + 1'b1;
      counter_x_hi <= 0;
      counter_scale <= 0;
    end else begin
      red_p   <= palette_r[fetch_buffer[counter_8x][15:8]];
      green_p <= palette_g[fetch_buffer[counter_8x][15:8]];
      blue_p  <= palette_b[fetch_buffer[counter_8x][15:8]];
      counter_x_hi <= 1;
      counter_scale <= 0;
    end
  end else if (colormode==1) begin
    // decode 16 to 24 bit color
    if (counter_scale != scalemode) begin
      counter_scale <= counter_scale + 1'b1;
    end else begin
      counter_scale <= 0;
      rgb <= fetch_buffer[counter_8x];
      counter_8x <= counter_8x + 1'b1;
    end
  
    red_p[0] <= rgb[0];
    red_p[1] <= rgb[0];
    red_p[2] <= rgb[1];
    red_p[3] <= rgb[1];
    red_p[4] <= rgb[2];
    red_p[5] <= rgb[2];
    red_p[6] <= rgb[3];
    red_p[7] <= rgb[4];
    
    green_p[0] <= rgb[5];
    green_p[1] <= rgb[5];
    green_p[2] <= rgb[6];
    green_p[3] <= rgb[6];
    green_p[4] <= rgb[7];
    green_p[5] <= rgb[8];
    green_p[6] <= rgb[9];
    green_p[7] <= rgb[10];
    
    blue_p[0] <= rgb[11];
    blue_p[1] <= rgb[11];
    blue_p[2] <= rgb[12];
    blue_p[3] <= rgb[12];
    blue_p[4] <= rgb[13];
    blue_p[5] <= rgb[13];
    blue_p[6] <= rgb[14];
    blue_p[7] <= rgb[15];
  end else if (colormode==2) begin
    // true color!
    if (counter_scale != scalemode) begin
      counter_scale <= counter_scale + 1'b1;
    end else begin
      counter_scale <= 0;
      counter_8x <= counter_8x + 1'b1;
      display_x2 <= display_x2 + 2'b10;
      display_x3 <= display_x3 + 2'b10;
    end
    
    rgb32 <= {fetch_buffer[display_x3],fetch_buffer[display_x2]};
    red_p   <= rgb32[15:8];
    green_p <= rgb32[7:0];
    blue_p <= rgb32[31:24];
  end else begin
    red_p   <= 0;
    green_p <= 0;
    blue_p  <= 0;
  end
end

endmodule
