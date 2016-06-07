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
// Description: 
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
//input videoR1,
//input videoR0,
input videoG3,
input videoG2,
input videoG1,
input videoG0,
//input videoB3,
//input videoB2,
input videoB1,
input videoB0,

// debug uart
output uartTX,
input uartRX,

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

reg uart_reset = 0;
reg [7:0] uart_data;
reg uart_write = 0;
reg uart_clk = 0;

uart uart(
  .uart_tx(uartTX),
  
  .uart_busy(uart_busy),   // High means UART is transmitting
  .uart_wr_i(uart_write),   // Raise to transmit byte
  .uart_dat_i(uart_data),  // 8-bit data
  .sys_clk_i(uart_clk),   // 115200Hz
  .sys_rst_i(uart_reset)    // System reset
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
wire data_out_queue_empty;
wire [4:0] sdram_state;
wire sdram_btb;
reg  [15:0] ram_data_in;
reg  ram_write = 0;
reg  ram_burst = 0;
reg  [1:0]  ram_byte_enable;

//synthesis attribute ram_style of fetch_buffer is block
reg  [15:0] fetch_buffer [0:1299];

reg  [10:0] fetch_x = 0;
reg  [10:0] fetch_x2 = 0;
reg  [10:0] fetch_y = 0;
reg  fetching = 0;

parameter capture_mode = 0;

reg z_ready = 'bZ;
assign zXRDY = z_ready;


reg display_enable = 1;
reg [15:0] glitchx_reg = 0; // 8f0012
reg [15:0] glitchx2_reg = 'h1fd; // 8f0010
//parameter glitchx_reg = 'h1fa;
reg  [8:0] ram_burst_col = 'h1fe; //'b111111010; 8f0014

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
  
  // Read data port
  .data_out(ram_data_out),
  .data_out_ready(data_out_ready),
  .data_out_queue_empty(data_out_queue_empty),
  .sdram_state(sdram_state),
  .sdram_btb(sdram_btb),
  .burst(ram_burst),

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

// zorro port buffers / flags

reg [23:0] zaddr;
reg [23:0] zaddr_sync;
reg [23:0] zaddr_sync2;
reg [15:0] data;
reg [15:0] data_in;
reg [15:0] zdata_in_sync;
reg dataout = 0;
reg dataout_enable = 0;
reg slaven = 0;

assign zDIR     = !(dataout_enable);
assign znSLAVEN = !(dataout && slaven);
assign zD  = (dataout) ? data : 16'bzzzz_zzzz_zzzz_zzzz;

// zorro synchronizers
// (inspired by https://github.com/endofexclusive/greta/blob/master/hdl/bus_interface/bus_interface.vhdl)

reg [1:0] znAS_sync  = 2'b11;
reg [2:0] znUDS_sync = 3'b000;
reg [2:0] znLDS_sync = 3'b000;
reg [1:0] znRST_sync = 2'b11;
reg [1:0] zREAD_sync = 2'b00;
reg [1:0] zDOE_sync = 2'b00;
reg [1:0] zE7M_sync = 2'b00;

reg [23:0] last_addr = 0;
reg [23:0] last_read_addr = 0;
reg [15:0] last_data = 0;
reg [15:0] last_read_data = 0;

// write queue

parameter max_fill = 255;
parameter q_msb = 21; // -> 20 bit wide RAM addresses (16-bit words) = 2MB
parameter lds_bit = q_msb+1;
parameter uds_bit = q_msb+2;
//synthesis attribute ram_style of writeq_addr is block
reg [(q_msb+2):0] writeq_addr [0:max_fill]; // 21=uds 20=lds
reg [15:0] writeq_data [0:max_fill-1];
reg [12:0] writeq_fill = 0;
reg [12:0] writeq_drain = 0;

reg [7:0] palette_r [0:255];
reg [7:0] palette_g [0:255];
reg [7:0] palette_b [0:255];

// 0 == 32 bit
// 1 == 16 bit
// 2 == 8 bit
reg [1:0] colormode = 1;
reg [1:0] scalemode = 0;

// memory map

parameter rom_low  = 24'he80000; // actually this is autoconf
parameter rom_high = 24'he80080;
reg [23:0] ram_low  = 24'h600000;
parameter ram_size = 24'h2d0000;
parameter reg_base = 24'h2f0000;
reg [23:0] ram_high = 24'h600000 + ram_size;
reg [23:0] reg_low  = 24'h600000 + reg_base;
reg [23:0] reg_high = 24'h600800 + reg_base;
parameter io_low  = 24'hde0000;
parameter io_high = 24'hde0010;

reg [7:0] fetch_delay = 0;
reg [7:0] read_counter = 0;
reg [7:0] fetch_delay_value = 'h04; // 8f0004
reg [7:0] margin_x = 5; // 8f0006

//parameter margin_x = 4;

reg [7:0] dataout_time = 'h02; // 8f000a
reg [7:0] slaven_time = 'h03; // 8f000c
reg [7:0] zready_time = 'h23; // 8f000e
reg [7:0] read_to_fetch_time = 'h2c; // 8f0002

// blitter registers

reg [10:0] blitter_x1 = 0;     // 20
reg [10:0] blitter_y1 = 0;     // 22
reg [10:0] blitter_x2 = 1279;  // 24
reg [10:0] blitter_y2 = 719;   // 26
reg [10:0] blitter_x3 = 0; // 2c
reg [10:0] blitter_y3 = 0; // 2e
reg [10:0] blitter_x4 = 'h100; // 30
reg [10:0] blitter_y4 = 'h100; // 32
reg [15:0] blitter_rgb = 'h0008; // 28
reg [15:0] blitter_copy_rgb = 'h0000;
reg [3:0]  blitter_enable = 1; // 2a
reg [10:0] blitter_curx = 0;
reg [10:0] blitter_cury = 0;
reg [10:0] blitter_curx2 = 0;
reg [10:0] blitter_cury2 = 0;

reg write_stall = 0;

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

// main FSM

parameter RESET = 0;
parameter CONFIGURING = 1;
parameter IDLE = 2;
parameter WAIT_READ = 3;
parameter WAIT_WRITE = 4;
parameter WAIT_READ_ROM = 5;
parameter WAIT_WRITE2 = 6;
parameter WAIT_READ2 = 7;
parameter CONFIGURED = 8;
reg [6:0] zorro_state = CONFIGURED;
wire [23:0] zaddr_regpart;
wire [23:0] zaddr_byte;

assign datastrobe_synced = ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0)));
assign zaddr_in_ram = (znAS_sync[1]==0 && znAS_sync[0]==0 && zaddr_sync==zaddr && zaddr_sync==zaddr_sync2 && zaddr_sync2>=ram_low && zaddr_sync2<ram_high);
assign zaddr_in_reg = (znAS_sync[1]==0 && znAS_sync[0]==0 && zaddr_sync==zaddr && zaddr_sync==zaddr_sync2 && zaddr_sync2>=reg_low && zaddr_sync2<reg_high);
assign zaddr_autoconfig = (znAS_sync[1]==0 && znAS_sync[0]==0 && zaddr_sync==zaddr && zaddr_sync==zaddr_sync2 && zaddr_sync2>=rom_low && zaddr_sync2<rom_high);
assign zorro_read = (zREAD_sync[1]); // & zREAD_sync[0]);
assign zorro_write = (!zREAD_sync[1]); //& !zREAD_sync[0]);
assign zaddr_regpart = zaddr_sync2&24'hffff;
assign zaddr_byte = (zaddr_sync2&24'hfff)>>1;

reg row_fetched = 0;

always @(posedge z_sample_clk) begin
  znUDS_sync  <= {znUDS_sync[1:0],znUDS};
  znLDS_sync  <= {znLDS_sync[1:0],znLDS};
  znAS_sync   <= {znAS_sync[0],znAS};
  zREAD_sync  <= {zREAD_sync[0],zREAD};
  zDOE_sync   <= {zDOE_sync[0],zDOE};
  zE7M_sync   <= {zE7M_sync[0],zE7M};
  znRST_sync  <= {znRST_sync[0],znRST};
  
  data_in <= zD;
  zdata_in_sync <= data_in;
  zaddr <= zA;
  zaddr_sync <= zaddr;
  zaddr_sync2 <= zaddr_sync;
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
parameter RAM_READING_ZORRO = 5;
parameter RAM_WRITING_ZORRO = 6;
parameter RAM_BURST_OFF = 7;
parameter RAM_BURST_ON = 8;

/*reg [5:0] uart_nybble = 0;

reg [15:0] time_ns = 0;
reg [2:0] time_corr = 0;

always @(posedge vga_clk) begin
  // 75mhz to nanosecond clock
  if (time_corr==2) begin
    time_corr <= 0;
    time_ns <= time_ns + 13;
  end else begin
    time_corr <= time_corr + 1;
    time_ns <= time_ns + 14;
  end
  
  if (time_ns>=4340) begin
    time_ns <= 0;
    uart_clk = ~uart_clk;
  end
end*/

reg need_row_fetch = 0;

// =================================================================================
// ZORRO MACHINE
always @(posedge z_sample_clk) begin
  LEDS <= zorro_state|(ram_arbiter_state<<5);
  
  case (zorro_state)
    RESET: begin
      dataout_enable <= 0;
      dataout <= 0;
      slaven <= 0;
      z_ready <= 1'bZ; // clear XRDY (cpu wait)
      zorro_ram_write_done <= 1;
      zorro_ram_read_done <= 1;
      blitter_rgb <= 'h0005;
      blitter_enable <= 1;
      
      ram_low   <= 'h600000;
      ram_high  <= 'h600000 + ram_size;
      reg_low   <= 'h600000 + reg_base;
      reg_high  <= 'h600000 + reg_base + 'h800;
      
      zorro_state <= CONFIGURING;
    end
    
    CONFIGURING: begin
      if (zaddr_autoconfig && !znCFGIN) begin
        if (zorro_read) begin
          // read iospace 'he80000 (Autoconfig ROM)
          dataout_enable <= 1;
          dataout <= 1;
          slaven <= 1;
          
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
        end else begin
          // write to autoconfig register
          /*if (datastrobe_synced) begin
            case (zaddr & 'h0000ff)
              'h000048: begin
                ram_low[23:20] <= data_in[15:12];
              end
              'h00004a: begin
                ram_low[19:16] <= data_in[15:12];
                ram_high  <= ram_low + ram_size;
                reg_low   <= ram_low + reg_base;
                reg_high  <= ram_low + reg_base + 'h800;
                zorro_state <= CONFIGURED; // configured
              end
              'h00004c: begin 
                zorro_state <= CONFIGURED; // configured, shut up
              end
            endcase
          end*/
        end
      end else begin
        // no address match
        dataout <= 0;
        dataout_enable <= 0;
        slaven <= 0;
      end
    end
      
    CONFIGURED: begin
      blitter_rgb <= 'hffff;
      blitter_enable <= 0;
      zorro_state <= IDLE;    
    end
  
    // ----------------------------------------------------------------------------------  
    IDLE: begin
      dataout <= 0;
      dataout_enable <= 0;
      slaven <= 0;
      write_stall <= 0;
      z_ready <= 1'bZ; // clear XRDY (cpu wait)
      
      if (znRST_sync[1]==0) begin
        // system reset
        zorro_state <= IDLE;
      end else if (znAS_sync[1]==0 && znAS_sync[0]==0) begin
        if (zorro_read && zaddr_in_ram) begin
          // read RAM
          // request ram access from arbiter
          zorro_ram_read_addr <= ((zaddr_sync2-ram_low)>>1);
          zorro_ram_read_request <= 1;
          zorro_ram_read_done <= 0;
          data <= 'hffff;
          read_counter <= 0;
          
          slaven <= 1;
          dataout_enable <= 1;
          dataout <= 1;
          
          z_ready <= 0;
          zorro_state <= WAIT_READ2;
          
        end else if (zorro_write && zaddr_in_ram) begin
          // write RAM
          
          last_addr <= ((zaddr_sync2-ram_low)>>1);
          zorro_state <= WAIT_WRITE;
          
        end else if (zorro_write && zaddr_in_reg && datastrobe_synced) begin
          // write to register
          
          if (zaddr_regpart>='h600) begin
            palette_r[zaddr_byte] <= data_in[7:0];
          end else if (zaddr_regpart>='h400) begin
            palette_g[zaddr_byte] <= data_in[7:0];
          end else if (zaddr_regpart>='h200) begin
            palette_b[zaddr_byte] <= data_in[7:0];
          end else
          case (zaddr_regpart)
            'h02: colormode <= data_in[1:0];
            'h04: scalemode <= data_in[1:0];
            
            'h0a: dataout_time <= data_in[7:0];
            'h06: margin_x <= data_in[7:0];
            'h10: glitchx2_reg <= data_in[15:0];
            'h12: glitchx_reg <= data_in[15:0];
            'h14: ram_burst_col <= data_in[8:0];
            
            // blitter regs
            'h20: blitter_x1 <= data_in[10:0];
            'h22: blitter_y1 <= data_in[10:0];
            'h24: blitter_x2 <= data_in[10:0];
            'h26: blitter_y2 <= data_in[10:0];
            'h28: blitter_rgb <= data_in[15:0];
            'h2a: begin
              blitter_enable <= data_in[3:0];
              blitter_curx <= blitter_x1;
              blitter_cury <= blitter_y1;
              blitter_curx2 <= blitter_x3;
              blitter_cury2 <= blitter_y3;
            end
            'h2c: blitter_x3 <= data_in[10:0];
            'h2e: blitter_y3 <= data_in[10:0];
            'h30: blitter_x4 <= data_in[10:0];
            'h32: blitter_y4 <= data_in[10:0];
            
            // sd card regs
            'h60: sd_reset <= data_in[8];
            'h62: sd_read <= data_in[8];
            'h64: sd_write <= data_in[8];
            'h66: sd_handshake_in <= data_in[8];
            'h68: sd_addr_in[31:16] <= data_in;
            'h6a: sd_addr_in[15:0] <= data_in;
            'h6c: sd_data_in <= data_in[15:8];
          endcase
        end else if (zorro_read && zaddr_in_reg) begin
          // read from registers
          
          dataout_enable <= 1;
          dataout <= 1;
          slaven <= 1;
          
          case (zaddr_regpart)
            'h20: data <= blitter_x1;
            'h22: data <= blitter_y1;
            'h24: data <= blitter_x2;
            'h26: data <= blitter_y2;
            'h28: data <= blitter_rgb;
            'h2a: data <= blitter_enable;
            
            'h60: data <= sd_busy<<8;
            'h62: data <= sd_read<<8;
            'h64: data <= sd_write<<8;
            'h66: data <= sd_handshake_out<<8;
            'h68: data <= sd_addr_in[31:16];
            'h6a: data <= sd_addr_in[15:0];
            'h6c: data <= sd_data_in<<8;
            'h6e: data <= sd_data_out<<8;
            'h70: data <= sd_error;
            
            default: data <= 'h0000;
          endcase
         
        end        
      end
    end
  
    // ----------------------------------------------------------------------------------
    WAIT_READ2: begin
      if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        // ram too slow TODO: report this
        zorro_ram_read_request <= 0;
        zorro_state <= IDLE;
        z_ready <= 1'bZ;
      end else if (zorro_ram_read_done) begin
        read_counter <= read_counter + 1;
        zorro_ram_read_request <= 0;
        
        if (read_counter >= dataout_time) begin
          zorro_state <= WAIT_READ;
        end
        data <= zorro_ram_read_data;
      end
    end
  
    // ----------------------------------------------------------------------------------
    WAIT_READ:
      if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        zorro_state <= IDLE;
        z_ready <= 1'bZ;
      end else begin
        data <= zorro_ram_read_data;
        z_ready <= 1'bZ;
      end
   
    // ----------------------------------------------------------------------------------
    WAIT_WRITE:
      if (!zorro_ram_write_request) begin
        // there is still room in the queue
        z_ready <= 1'bZ;
        write_stall <= 0;
        if (datastrobe_synced && zdata_in_sync==data_in) begin
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
      z_ready <= 1'bZ;
      if (znAS_sync[1]==1 && znAS_sync[0]==1) begin
        zorro_state <= IDLE;
      end
    end
    
  endcase

// =================================================================================
// RAM ARBITER

  case (ram_arbiter_state)
    RAM_READY: begin
      ram_enable <= 1;
      ram_arbiter_state <= RAM_READY2;
    end
    
    RAM_READY2: begin
      // start fetching a row
      ram_addr  <= ((fetch_y << 11)|glitchx2_reg);
      ram_write <= 0;
      ram_byte_enable <= 'b11;
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
      if (cmd_ready) ram_arbiter_state <= RAM_FETCHING_ROW8;
    end
    
    RAM_BURST_OFF: begin
      ram_enable <= 0;
      if (data_out_queue_empty && cmd_ready)
        ram_arbiter_state <= RAM_ROW_FETCHED;
    end
    
    RAM_FETCHING_ROW8: begin
      if (fetch_x == screen_w) begin
        row_fetched <= 1; // row completely fetched
        ram_arbiter_state <= RAM_READY;
      end
      
      if (data_out_ready) begin
        ram_enable <= 1;
        ram_write <= 0;
        ram_byte_enable <= 'b11;
        ram_addr  <= ((fetch_y << 11) | fetch_x2); // burst incremented
      
        fetch_x <= fetch_x + 1;
        fetch_x2 <= fetch_x2 + 1;
        fetch_buffer[fetch_x] <= ram_data_out;
      end
    end
      
    RAM_ROW_FETCHED:
      if (need_row_fetch) begin
        row_fetched <= 0;
        fetch_x <= 0;
        fetch_y <= counter_y;
        ram_arbiter_state <= RAM_READY;
        
        //if (blitter_enable>2) blitter_enable <= 2;
        
      // BLITTER ----------------------------------------------------------------
      end else if (blitter_enable==1 && cmd_ready) begin
        // rect fill blitter
        if (blitter_curx<=blitter_x2) begin
          blitter_curx <= blitter_curx + 1;
          ram_byte_enable <= 'b11;
          ram_addr    <= (blitter_cury<<11)|blitter_curx;          
          ram_data_in <= blitter_rgb;
          ram_write   <= 1;
          ram_enable  <= 1;
        end else if (blitter_cury<blitter_y2) begin
          blitter_cury <= blitter_cury + 1;
          blitter_curx <= blitter_x1;
        end else begin
          blitter_curx <= 0;
          blitter_cury <= 0;
          blitter_enable <= 0;
          //ram_enable <= 0;
        end
      end else if (blitter_enable>1 && counter_x<1300) begin
        if (blitter_enable==2 && cmd_ready) begin
          // block copy (read)
          if (blitter_curx2!=blitter_x4) begin
            blitter_enable <= 3; // wait for read
          end else if (blitter_cury2<blitter_y4) begin
            blitter_curx <= blitter_x1;
            blitter_curx2 <= blitter_x3;
            blitter_cury <= blitter_cury + 1;
            blitter_cury2 <= blitter_cury2 + 1;
            blitter_enable <= 3; // wait for read
          end else if (blitter_cury2>blitter_y4) begin
            blitter_curx <= blitter_x1;
            blitter_curx2 <= blitter_x3;
            blitter_cury <= blitter_cury - 1;
            blitter_cury2 <= blitter_cury2 - 1;
            blitter_enable <= 3; // wait for read
          end else begin
            blitter_enable <= 0;
            //ram_enable <= 0;
          end
        end else if (blitter_enable==3) begin        
          ram_byte_enable <= 'b11;
          ram_addr    <= (blitter_cury2<<11)|blitter_curx2;
          ram_write   <= 0;
          ram_enable  <= 1;
          // block copy (data ready)
          if (data_out_ready) begin
            blitter_copy_rgb <= ram_data_out;
            blitter_enable <= 4;
          end
        end else if (blitter_enable==4) begin
          if (blitter_curx2>blitter_x4) begin
            blitter_curx2 <= blitter_curx2 - 1;
            blitter_curx  <= blitter_curx - 1;
          end else if (blitter_curx2<blitter_x4) begin
            blitter_curx2 <= blitter_curx2 + 1;
            blitter_curx  <= blitter_curx + 1;
          end
          
          blitter_enable <= 5;
          ram_addr    <= (blitter_cury<<11)|blitter_curx;  
          ram_data_in <= blitter_copy_rgb;
          ram_write   <= 1;
          ram_enable  <= 1;
          ram_byte_enable <= 'b11;
        end else if (blitter_enable==5 && cmd_ready) begin
          blitter_enable <= 2;
        end
      
      // ZORRO READ/WRITE ----------------------------------------------
      end else if (zorro_ram_read_request && counter_x<1300) begin
        // process read request
        zorro_ram_read_done <= 0;
        if (cmd_ready && data_out_queue_empty) begin
          ram_write <= 0;
          ram_addr <= zorro_ram_read_addr;
          ram_byte_enable <= 'b11;
          ram_enable <= 1;
          ram_arbiter_state <= RAM_READING_ZORRO;
        end else 
          ram_enable <= 0;
      end else if (zorro_ram_write_request && cmd_ready) begin
        // process write request
        zorro_ram_write_done <= 1;
        zorro_ram_write_request <= 0;
        
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
      
    RAM_READING_ZORRO: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        zorro_ram_read_data <= ram_data_out;
        zorro_ram_read_done <= 1;
        zorro_ram_read_request <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_WRITING_ZORRO: begin
      ram_enable <= 0;
      ram_arbiter_state <= RAM_ROW_FETCHED;
    end
    
  endcase
end

reg[23:0] rgb = 'h0000;
reg[11:0] counter_8x = 0;
reg counter_x_hi = 1;
reg scale_xc = 0;
reg[7:0] pidx;
reg[15:0] fetchb1;

//wire[11:0] fetch_x_next = fetch_x + 1;
//wire[11:0] fetch_x2_next = fetch_x2 + 1;


always @(posedge vga_clk) begin
  if (counter_x >= h_max) begin
    counter_x <= 0;
    counter_8x <= margin_x;
    counter_x_hi <= 1;
    display_x <= margin_x;
    
    if (counter_y == v_max) begin
      counter_y <= 0;
    end else
      counter_y <= counter_y + 1;
  end else begin
    counter_x <= counter_x + 1;
    // TODO left margin
    display_x <= display_x + 1;
    
    if (counter_x>=h_max-64 && counter_y<screen_h)
      need_row_fetch <= 1;
    else
      need_row_fetch <= 0;

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
  
  if (dvi_blank || (counter_x>=screen_w) || (counter_y>=screen_h)) begin
    red_p   <= 0;
    green_p <= 0;
    blue_p  <= 0;
  end else if (colormode==0) begin
    // 0: +0a +0b +1a
    // 1: +0b +1a +1b
    fetchb1 <= fetch_buffer[counter_8x];
    
    if (counter_x_hi) begin
      pidx   <= fetchb1[7:0];
      counter_x_hi <= 0;
    end else begin
      pidx   <= fetchb1[15:8];
      counter_x_hi <= 1;
      counter_8x <= counter_8x + 1;
    end
    
    red_p <= palette_r[pidx];
    green_p <= palette_g[pidx];
    blue_p <= palette_b[pidx];
    
  end else if (colormode==1) begin
    // decode 16 to 24 bit color
    rgb <= fetch_buffer[display_x];
    
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
  end
end

endmodule
