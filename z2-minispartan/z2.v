`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: MNT Media and Technology UG
// Engineer: Lukas F. Hartmann (@mntmn)
// 
// Create Date:    21:49:19 03/22/2016 
// Design Name:    Amiga 2000 Graphics Card (VA2000)
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
output znCFGOUT,
output znSLAVEN,
output zXRDY,
input znBERR,
input znRST,
input zE7M,
input zREAD,
input zDOE,

// address bus
input znAS,
input znUDS,
input znLDS,
input [23:0] zA,

// data bus
output zDIR,
inout [15:0] zD,

// video slot input
input videoVS,
input videoHS,
input videoR3,
input videoR2,
input videoR1,
input videoR0,
input videoG3,
input videoG2,
input videoG1,
input videoG0,
//input videoB3,
//input videoB2,
input videoB1,
input videoB0,

// SD
output SD_nCS,
output SD_MOSI,
input  SD_MISO,
output SD_SCLK,

// leds
output reg [7:0] LEDS = 0,

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

`ifndef SIMULATION
clk_wiz_v3_6 DCM(
  .CLK_IN1(CLK50),
  .CLK_OUT100(z_sample_clk),
  .CLK_OUT75(vga_clk)
);

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
  .hndShk_o(sd_handshake_out)
);

`endif

wire sdram_reset;
reg  ram_enable = 0;
reg  [23:0] ram_addr = 0;
wire [15:0] ram_data_out;
wire data_out_ready;
reg  [15:0] ram_data_in;
reg  ram_write = 0;
reg  [1:0]  ram_byte_enable;
reg  [15:0] ram_data_buffer [0:1299]; // 16bpp line buffer
reg  [10:0] fetch_x = 0;
reg  [10:0] fetch_y = 0;
reg  fetching = 0;

parameter capture_mode = 0;

reg z_ready = 'bZ;
assign zXRDY = z_ready;

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
  .tmds_out_n(tmds_out_nbuf)
);
`endif

assign sdram_reset = 0;

// vga registers
reg [11:0] counter_x = 0;
reg [11:0] counter_y = 0;
reg [11:0] display_x = 0;

parameter h_rez        = 1280;
parameter h_sync_start = h_rez+72;
parameter h_sync_end   = h_rez+80;
parameter h_max        = 1647;

parameter v_rez        = 720;
parameter v_sync_start = v_rez+3;
parameter v_sync_end   = v_rez+3+5;
parameter v_max        = 749;

parameter screen_w = 1280;
parameter screen_h = 720;

reg [23:0] zaddr;
reg [23:0] zaddr_sync;
reg [15:0] data;
reg [15:0] data_in;
reg dataout = 0;
reg dataout_enable = 0;

reg slaven = 0;

assign zDIR     = !(dataout_enable);
assign znSLAVEN = !(dataout && slaven);
assign zD  = (dataout) ? data : 16'bzzzz_zzzz_zzzz_zzzz;

reg [23:0] last_addr = 0;
reg [23:0] last_read_addr = 0;
reg [15:0] last_data = 0;
reg [15:0] last_read_data = 0;

reg host_reading = 0;
reg write_clocked = 0;
reg byte_ena_clocked = 0;

parameter max_fill = 256;
parameter q_msb = 21; // -> 20 bit wide RAM addresses (16-bit words) = 2MB
parameter lds_bit = q_msb+1;
parameter uds_bit = q_msb+2;

reg [(q_msb+2):0] writeq_addr [0:max_fill-1]; // 21=uds 20=lds
reg [15:0] writeq_data [0:max_fill-1];
reg [12:0] writeq_fill = 0;
reg [12:0] writeq_drain = 0;

reg [1:0] znAS_sync  = 2'b11;
reg [2:0] znUDS_sync = 3'b000;
reg [2:0] znLDS_sync = 3'b000;
reg [1:0] zREAD_sync = 2'b00;
reg [1:0] zDOE_sync = 2'b00;
reg [1:0] zE7M_sync = 2'b00;

reg [6:0] state = 0;
reg row_fetched = 0;
parameter IDLE = 0;
parameter WAIT_READ = 1;
parameter WAIT_WRITE = 2;
parameter WAIT_READ_ROM = 4;
parameter WAIT_WRITE2 = 8;
parameter WAIT_READ2 = 16;

// 'h300000 = 3MB

/*parameter ram_low  = 24'h600000;
parameter ram_high = 24'h8d0000;
parameter reg_low  = 24'h8f0000;
parameter reg_high = 24'h8f0100;*/

parameter rom_low  = 24'he80000;
parameter rom_high = 24'he80080;
reg [23:0] ram_low  = 24'h600000;
parameter ram_size = 24'h2d0000;
parameter reg_base = 24'h2f0000;
reg [23:0] ram_high = 24'h600000 + ram_size;
reg [23:0] reg_low  = 24'h600000 + reg_base;
reg [23:0] reg_high = 24'h600100 + reg_base;


parameter io_low  = 24'hde0000;
parameter io_high = 24'hde0010;

reg [7:0] fetch_delay = 0;
reg [7:0] read_counter = 0;
reg [7:0] fetch_delay_value = 'h09; // 8f0004
reg [7:0] margin_x = 0; // 8f0006

reg [7:0] dataout_time = 'h03; // 8f000a
reg [7:0] slaven_time = 'h03; // 8f000c
reg [7:0] zready_time = 'h23; // 8f000e
reg [7:0] read_to_fetch_time = 'h2c; // 8f0002

// registers
reg display_enable = 1;
reg [7:0] fetch_preroll = 'h20;

reg [7:0]  glitch_reg = 'h09; // 8f0010
reg [11:0] glitchx_reg = 'h1fe; // 'h203; // 8f0012
reg [7:0]  glitch_offset = 8; // 8f0014
reg [7:0]  negx_margin = 5; // 8f0016

reg write_stall = 0;
//reg [4:0] write_cooldown = 0;

// video capture regs
reg[13:0] capture_x = 0;
reg[13:0] capture_y = 0;
reg[7:0] vvss = 1;
reg video_synced = 0;
reg [7:0] delay_lines = 0;
reg [7:0] vsync_count = 0;
reg [7:0] hsync_count = 0;

reg z_confdone = 0;
assign znCFGOUT = ~z_confdone;

always @(posedge z_sample_clk) begin
  // synchronizers (inspired by https://github.com/endofexclusive/greta/blob/master/hdl/bus_interface/bus_interface.vhdl)
  znUDS_sync  <= {znUDS_sync[1:0],znUDS};
  znLDS_sync  <= {znLDS_sync[1:0],znLDS};
  znAS_sync   <= {znAS_sync[0],znAS};
  zREAD_sync  <= {zREAD_sync[0],zREAD};
  zDOE_sync   <= {zDOE_sync[0],zDOE};
  zE7M_sync   <= {zE7M_sync[0],zE7M};
  
  data_in <= zD;
  zaddr <= zA;
  zaddr_sync <= zaddr;
  
  if (!znRST) begin
    // system reset!
    z_confdone <= 0;
  end
  
  if (state == IDLE) begin
    dataout <= 0;
    dataout_enable <= 0;
    slaven <= 0;
    write_stall <= 0;
    
    if (znAS_sync[1]==0) begin
      // zorro gives us an address
      
      if (zREAD_sync[1]==1 && zaddr_sync==zaddr && zaddr>=ram_low && zaddr<ram_high) begin
        // read RAM

        //last_addr <= zaddr;
        last_read_addr <= ((zaddr_sync-ram_low)>>1);
        dataout_enable <= 0;
        dataout <= 0;
        data <= 'hffff;
        last_read_data <= 'hffff;
        read_counter <= 0;
        
        z_ready <= 0;
        state <= WAIT_READ2;
        
      end else if (zREAD_sync[1]==1 && ((zaddr>=rom_low && zaddr<rom_high && !znCFGIN && !z_confdone))) begin
        // read iospace 'he80000 (ROM)
        
        dataout_enable <= 1;
        dataout <= 1;
        slaven <= 1;
        last_addr <= zaddr;
        LEDS <= (zaddr & 'h0000ff);
        
        case (zaddr & 'h0000ff)
          'h000000: data <= 'b1100_0000_0000_0000; // zorro 2
          'h000002: data <= 'b0111_0000_0000_0000; // 2mb
          
          'h000004: data <= 'b1111_0000_0000_0000; // product number
          'h000006: data <= 'b1110_0000_0000_0000; // (23)
          
          'h000008: data <= 'b0011_0000_0000_0000; // flags inverted
          'h00000a: data <= 'b1111_0000_0000_0000; // inverted zero
          
          'h000010: data <= 'b1111_0000_0000_0000; // manufacturer high byte inverted (02)
          'h000012: data <= 'b1101_0000_0000_0000; // 
          'h000014: data <= 'b0110_0000_0000_0000; // manufacturer low byte (9a)
          'h000016: data <= 'b0101_0000_0000_0000;
          
          'h000018: data <= 'b1111_0000_0000_0000; // serial
          'h00001a: data <= 'b1110_0000_0000_0000; //
          'h00001c: data <= 'b1111_0000_0000_0000; //
          'h00001e: data <= 'b1110_0000_0000_0000; //
          'h000020: data <= 'b1111_0000_0000_0000; //
          'h000022: data <= 'b1110_0000_0000_0000; //
          'h000024: data <= 'b1111_0000_0000_0000; //
          'h000026: data <= 'b1110_0000_0000_0000; //
          
          'h000040: data <= 'b0000_0000_0000_0000; // interrupts (not inverted)
          'h000042: data <= 'b0000_0000_0000_0000; //
         
          default: data <= 'b1111_0000_0000_0000;
        endcase
        state <= WAIT_READ_ROM;
        
      end else if (zREAD_sync[1]==0 && zaddr>=rom_low && zaddr<rom_high && !znCFGIN) begin
        // write to autoconfig register
        if ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
          case (zaddr & 'h0000ff)
            'h000048: begin
              ram_low[23:20] <= data_in[15:12];
              LEDS <= 'hff;
            end
            'h00004a: begin
              ram_low[19:16] <= data_in[15:12];
              ram_high  <= ram_low + ram_size;
              reg_low   <= ram_low + reg_base;
              reg_high  <= ram_low + reg_base + 'h100;
              z_confdone <= 1;
              LEDS <= 'hfe;
            end
            'h00004c: begin 
              z_confdone <= 1;
              LEDS <= 'hf0; // shut up register
            end
          endcase
        end
      
      end else if (zREAD_sync[1]==0 && zaddr>=reg_low && zaddr<reg_high) begin
        // write to register
        if ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
          case (zaddr & 'h0000ff)
            'h00: display_enable <= data_in[0];
            'h02: read_to_fetch_time <= data_in[7:0];
            'h04: fetch_delay_value <= data_in[7:0];
            'h06: margin_x <= data_in[7:0];
            'h08: fetch_preroll <= data_in[7:0];
            'h0a: dataout_time <= data_in[7:0];
            'h0c: slaven_time <= data_in[7:0];
            'h0e: zready_time <= data_in[7:0];
            'h10: glitch_reg <= data_in[7:0];
            'h12: glitchx_reg <= data_in[11:0];
            'h14: glitch_offset <= data_in[7:0];
            'h16: negx_margin <= data_in[7:0];
            
            // sd card regs
            'h30: sd_reset <= data_in[8];
            'h32: sd_read <= data_in[8];
            'h34: sd_write <= data_in[8];
            'h36: sd_handshake_in <= data_in[8];
            'h38: sd_addr_in[31:16] <= data_in[15:8];
            'h3a: sd_addr_in[15:0] <= data_in[15:8];
            'h3c: sd_data_in <= data_in[15:8];
          endcase
        end
      end else if (zREAD_sync[1]==1 && zaddr>=reg_low && zaddr<reg_high) begin
        // read from registers
        
        dataout_enable <= 1;
        dataout <= 1;
        slaven <= 1;
        last_addr <= zaddr;
        
        case (zaddr & 'h0000ff)
          'h20: data <= ram_low[23:16];
          'h22: data <= ram_low[15:0];
          'h24: data <= ram_high[23:16];
          'h26: data <= ram_high[15:0];
          
          'h30: data <= sd_busy<<8;
          'h32: data <= sd_read<<8;
          'h34: data <= sd_write<<8;
          'h36: data <= sd_handshake_out<<8;
          'h38: data <= sd_addr_in[31:16];
          'h3a: data <= sd_addr_in[15:0];
          'h3c: data <= sd_data_in<<8;
          'h3e: data <= sd_data_out<<8;
          'h40: data <= sd_error;
          
          default: data <= 'h0000;
        endcase
       
      end else if (zREAD_sync[1]==0 && zaddr>=ram_low && zaddr<ram_high) begin
        // write RAM
        
        dataout <= 0;
        //last_addr <= zaddr;
        
        if ((((zaddr-ram_low)>>1)&'h3ff) >= 'h200)
          last_addr <= ((zaddr-ram_low)>>1) + glitch_offset;
        else
          last_addr <= ((zaddr-ram_low)>>1);
        
        state <= WAIT_WRITE;
      end else
        dataout <= 0;
      
    end else
      dataout <= 0;
  
  end else if (state == WAIT_READ2) begin
  
    if (znAS_sync[1]==1) begin
      state <= IDLE;
      dataout <= 0;
      dataout_enable <= 0;
      slaven <= 0;
      z_ready <= 'bZ;
    end else if (!fetching && writeq_fill==0 && row_fetched && cmd_ready) begin
      state <= WAIT_READ;
      read_counter <= 0;
    end
  
  end else if (state == WAIT_READ) begin
    read_counter <= read_counter + 1;
    
    if (znAS_sync[1]==1) begin
      state <= IDLE;
      dataout <= 0;
      dataout_enable <= 0;
      slaven <= 0;
      z_ready <= 'bZ;
    end else begin
      if (read_counter>=dataout_time) begin
        dataout_enable <= 1;
        dataout <= 1;
      end
      if (read_counter>=slaven_time) begin
        slaven <= 1;
      end
      if (read_counter>=zready_time) begin
        z_ready <= 'bZ;
      end
      
      if (read_counter<read_to_fetch_time) begin
        //ram_enable <= 1;
        ram_write <= 0;
        
        if ((last_read_addr&'h0003ff) >= 'h000200)
          ram_addr <= (last_read_addr + glitch_offset);
        else
          ram_addr <= last_read_addr;
      
        ram_byte_enable <= 'b11;
        
        if (data_out_ready) begin
          last_read_data <= ram_data_out[15:0];
        end
      end
      
      data <= last_read_data;
    end

  end else if (state == WAIT_READ_ROM) begin
    if (znAS_sync[1]==1) begin
      state <= IDLE;
      dataout <= 0;
      dataout_enable <= 0;
      slaven <= 0;
    end else begin
      dataout <= 1;
      dataout_enable <= 1;
      slaven <= 1;
    end
   
  end else if (state == WAIT_WRITE) begin
    dataout <= 0;
    dataout_enable <= 0;
    
    // race conditions occur if writeq is mutated while read
    
    if (writeq_fill<max_fill-1) begin
      // there is still room in the queue
      z_ready <= 'bZ;
      write_stall <= 0;

      if ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
        last_data <= data_in;
          
        writeq_addr[writeq_fill][q_msb:0] <= last_addr;
        writeq_addr[writeq_fill][lds_bit] <= ~znLDS_sync[2];
        writeq_addr[writeq_fill][uds_bit] <= ~znUDS_sync[2];
        writeq_data[writeq_fill]          <= data_in;
        
        writeq_fill <= writeq_fill+1;
          
        state <= WAIT_WRITE2;
      end
    end else begin
      z_ready <= 0;
      write_stall <= 1;
    end
    
  end else if (state == WAIT_WRITE2) begin
    dataout <= 0;
    if (znAS_sync[1]==1) state <= IDLE;
  end
  
  //  && (!(zREAD_sync[1]==1 && zaddr>=ram_low && zaddr<ram_high) || znAS_sync[1]==1))
  
  if (state == WAIT_READ2 || state == WAIT_WRITE || state == WAIT_WRITE2 || state == IDLE ) begin
    if (fetching) begin
      if (fetch_delay<1 && data_out_ready) begin
        ram_data_buffer[fetch_x] <= ram_data_out[15:0];
        fetch_x <= fetch_x + 1;
        
        if (fetch_x > screen_w) begin
          fetching <= 0;
          fetch_x  <= 0;
          row_fetched <= 1; // row completely fetched
        end
      end
       
      // read window
      if (capture_mode) begin
        // double every second line
        ram_addr  <= (((fetch_y&'hfffe) << 11) + fetch_x);
      end else begin
        ram_addr  <= ((fetch_y << 11) + fetch_x);
      end
      ram_enable <= 1; // fetch next
      ram_byte_enable <= 'b11;
      ram_write <= 0;
    end
    
    if (fetching && fetch_delay>0) begin
      fetch_delay <= fetch_delay - 1;
    end
    
    if (display_enable && !row_fetched && !fetching && counter_y<screen_h) begin
      // fetch video pixels for current row as quickly as possible
      
      dataout <= 0;
      fetching <= 1;
      fetch_delay <= fetch_delay_value;
      fetch_x <= 0;
    end else if ((state == IDLE || state == WAIT_READ2 || (state == WAIT_WRITE && write_stall)) && !fetching && row_fetched) begin
      // write window
      if (cmd_ready && writeq_fill>0) begin
        if (writeq_addr[writeq_fill-1][uds_bit] && !writeq_addr[writeq_fill-1][lds_bit])
          ram_byte_enable <= 'b10; // UDS
        else if (writeq_addr[writeq_fill-1][lds_bit] && !writeq_addr[writeq_fill-1][uds_bit])
          ram_byte_enable <= 'b01; // LDS
        else
          ram_byte_enable <= 'b11;
        
        ram_data_in <= (writeq_data[writeq_fill-1]);
        ram_addr    <= (writeq_addr[writeq_fill-1][q_msb:0]);
        ram_write   <= 1;
        ram_enable  <= 1;
        
        writeq_fill <= writeq_fill-1;
        
        //write_cooldown <= 2;
      end
    end
  end
  
  if (capture_mode) begin
    if (!videoHS) begin
      hsync_count <= hsync_count + 1;
      if (hsync_count>50) begin
        capture_x <= 0;
        hsync_count <= 0;
      end
    end else begin
      hsync_count <= 0;
      capture_x <= capture_x + 1;
      
      if (capture_x == 1) begin
        capture_y <= capture_y + 1;
      end
      
      // FIXME no more space for videoB3, videoB2
      if (!fetching && ((capture_x&'b111)==0) && capture_y>0) begin
        ram_data_in <= {videoR3,videoR2,videoR1,videoR0,videoR0, videoG3,videoG2,videoG1,videoG0,videoG0,videoG0, videoB1,videoB1,videoB1,videoB0,videoB0};
        ram_addr    <= (capture_y<<12)+(capture_x>>3);
        ram_write   <= 1;
        ram_enable  <= 1;
      end
    end
    
    vvss[7] <= vvss[6];
    vvss[6] <= vvss[5];
    vvss[5] <= vvss[4];
    vvss[4] <= vvss[3];
    vvss[3] <= vvss[2];
    vvss[2] <= vvss[1];
    vvss[1] <= vvss[0];
    vvss[0] <= videoVS;
    
    if (vvss==0) begin
      vsync_count <= vsync_count + 1;
      if (vsync_count > 200) begin
        capture_y <= 0;
        video_synced <= 1;
        vsync_count <= 0;
      end
    end else begin
      video_synced <= 0;
      vsync_count <= 0;
    end
  end
  
  //if (writeq_fill==0 && write_cooldown>0) write_cooldown <= write_cooldown-1;
  
  if (counter_x==h_max-fetch_preroll && counter_y<screen_h) begin
    row_fetched <= 0;
    fetch_x <= 0;
    fetch_y <= counter_y;
  end
end

reg[15:0] rgb = 'h0000;

always @(posedge vga_clk) begin
  if (counter_x >= h_max) begin
    counter_x <= 0;
    display_x <= 0;
    
    if (counter_y == v_max) begin
      counter_y <= 0;
    end else
      counter_y <= counter_y + 1;
  end else begin
    counter_x <= counter_x + 1;
    
    if (counter_x==margin_x+glitchx_reg)
      display_x <= (display_x + glitch_reg);
    else if (counter_x>=margin_x)
      display_x <= display_x + 1;
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
    rgb <= 0;
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
  
  if (dvi_blank)
	    rgb <= 0;
	  else
      //rgb <= ram_data_buffer[counter_x];
      
      /*if (counter_y>710) begin
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
        else if (counter_x<(700+max_fill)) begin
          if (counter_y<550) 
            rgb <= writeq_fill>(counter_x-700)?16'hffff:16'h0000;        
          else
            rgb <= writeq_drain>(counter_x-700)?16'hffff:16'h0000;
        end else 
          rgb <= 0;
        end
      else begin*/
        if ((counter_x>=(screen_w+margin_x) || counter_x<margin_x) || counter_y>=screen_h)
          rgb <= 0;
        else begin
          if (capture_mode) begin
            rgb <= ram_data_buffer[counter_x];
          end else begin
            rgb <= ram_data_buffer[display_x+negx_margin];
          end
        end

end

endmodule
