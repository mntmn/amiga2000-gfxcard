`timescale 1ns / 1ns
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
input [23:0] zA,

// data bus
output zDIR,
inout [15:0] zD,

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
`endif

wire sdram_reset;
reg  ram_enable = 0;
reg  [23:0] ram_addr = 0;
wire [15:0] ram_data_out;
wire data_out_ready;
reg  [15:0] ram_data_in;
reg  ram_write = 0;
reg  [1:0]  ram_byte_enable;
reg  [15:0] ram_data_buffer [0:799]; // 1024x16bit line buffer
reg  [10:0] fetch_x = 0;
reg  fetching = 0;

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
reg [23:0] zaddr2;
reg [15:0] data;
reg [15:0] data_in;
reg dataout = 0;
reg dataout_enable = 0;

assign zDIR     = !(dataout_enable);
assign znSLAVEN = !(dataout);
assign zD  = (dataout) ? data : 16'bzzzz_zzzz_zzzz_zzzz;

reg [23:0] last_addr = 0;
reg [15:0] last_data = 0;

reg host_reading = 0;
reg write_clocked = 0;
reg byte_ena_clocked = 0;

parameter max_fill = 2100;
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

parameter ram_low  = 24'h600000;
parameter ram_high = 24'h740000;
parameter rom_low  = 24'he80000;
parameter rom_high = 24'he80100;

reg burst_enable = 0; // already triggered a burst for fetching consecutive pixels?
reg [4:0] wdelay = 0; // write switchoff delay (used at the end of draining write queue)
reg [4:0] read_delay = 0;
/*
parameter rec_depth = 16;

reg [23:0] rec_addr [0:rec_depth-1];
reg [15:0] rec_data [0:rec_depth-1];
reg rec_as [0:rec_depth-1];
reg rec_lds [0:rec_depth-1];
reg rec_uds [0:rec_depth-1];
reg rec_read [0:rec_depth-1];
reg rec_doe [0:rec_depth-1];
reg recording = 1;

reg [6:0] rec_idx; // up to rec_depth
reg [6:0] trigger_idx;
reg read_fetched = 0;
*/
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
  
  /*rec_addr[rec_idx] <= zaddr;
  rec_data[rec_idx] <= data_in;
  rec_as[rec_idx]   <= znAS_sync[1];
  rec_lds[rec_idx]  <= znLDS_sync[1];
  rec_uds[rec_idx]  <= znUDS_sync[1];
  rec_read[rec_idx] <= zREAD_sync[1];
  rec_doe[rec_idx]  <= zDOE_sync[1];
  
  if (rec_idx>=rec_depth-1) begin
    if (recording)
      rec_idx <= 0;
  end else
    rec_idx <= rec_idx+1;*/
   
  if (state == IDLE) begin
    dataout <= 0;
    
    if (znAS_sync[1]==0) begin
      // zorro gives us an address
      
      if (zREAD_sync[1]==1 && zaddr>=ram_low && zaddr<ram_high) begin
        // read RAM

        last_addr <= zaddr;
        dataout_enable <= 1;
        dataout <= 0;
        data <= 'hffff;
        
        ram_write <= 0;
        ram_addr <= ((zaddr&'h1ffffe)>>1);
        ram_enable <= 1;
        ram_byte_enable <= 'b11;
        fetching <= 0;
        burst_enable <= 0;
        
        state <= WAIT_READ;
                
      end else if (zREAD_sync[1]==1 && zaddr>=rom_low && zaddr<rom_high && !znCFGIN) begin
        // read iospace 'he80000 (ROM)
        dataout_enable <= 1;
        dataout <= 1;
        last_addr <= zaddr;
        
        case (zaddr & 'h0000ff)
          'h000000: data <= 'b1100_0000_0000_0000; // zorro 2
          'h000002: data <= 'b0111_0000_0000_0000; // 4mb, not linked
          'h000004: data <= 'b0001_0000_0000_0000; // product number
          'h000006: data <= 'b0111_0000_0000_0000; // (23)
          'h000008: data <= 'b0100_0000_0000_0000; // flags
          'h00000a: data <= 'b0000_0000_0000_0000; // sub size automatic
          'h00000c: data <= 'b0000_0000_0000_0000; // reserved
          'h00000e: data <= 'b0000_0000_0000_0000; // 
          'h000010: data <= 'b0110_0000_0000_0000; // manufacturer high byte
          'h000012: data <= 'b1101_0000_0000_0000; // 
          'h000014: data <= 'b0110_0000_0000_0000; // manufacturer low byte
          'h000016: data <= 'b1101_0000_0000_0000;
          'h000018: data <= 'b0000_0000_0000_0000; // reserved
          'h00001a: data <= 'b0000_0000_0000_0000; //
          //'h000044: z_state <= Z_CONF_DONE;
         
          default: data <= 'b0000_0000_0000_0000;	 
        endcase
        state <= WAIT_READ_ROM;
       
      end else if (zREAD_sync[1]==0 && zaddr>=ram_low && zaddr<ram_high) begin
        // write RAM
        
        dataout <= 0;
        last_addr <= zaddr;
        
        state <= WAIT_WRITE;
      end else
        dataout <= 0;
      
    end else if (!row_fetched && !fetching && counter_y<600 && ((writeq_fill-writeq_drain)<1000) ) begin
      // fetch video pixels for current row as quickly as possible
      
      burst_enable <= 1;
      dataout <= 0;
      fetching <= 1;
      fetch_x <= 0;
      ram_byte_enable <= 'b1111;
      ram_addr  <= ((counter_y << 10));
      ram_write <= 0;
      ram_enable <= 1;
    end else
      dataout <= 0;
  
  end else if (state == WAIT_READ || state == WAIT_READ2) begin
    if (data_out_ready && state == WAIT_READ) begin
      last_data <= ram_data_out[15:0];
      // problem: this will serve bursts to the host
      state <= WAIT_READ2;
    end
    
    if (znAS_sync[1]==1) begin
      state <= IDLE;
      dataout <= 0;
      dataout_enable <= 0;
      ram_enable <= 0;
    end else begin
      dataout <= 1;
      dataout_enable <= 1;
      data <= last_data;
    end

  end else if (state == WAIT_READ_ROM) begin
    if (znAS_sync[1]==1) begin
      state <= IDLE;
      dataout <= 0;
      dataout_enable <= 0;
    end else begin
      dataout <= 1;
      dataout_enable <= 1;
    end
   
  end else if (state == WAIT_WRITE) begin
    dataout <= 0;

    if ((znUDS_sync[2]==znUDS_sync[1]) && (znLDS_sync[2]==znLDS_sync[1]) && ((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
      //last_addr <= zaddr;
      last_data <= data_in;
    
      /*if (recording==0) begin
        recording <= 1;
        trigger_idx <= 0;
      end else begin
        recording <= 0;
        trigger_idx <= rec_idx;
      end*/
      
      writeq_addr[writeq_fill][q_msb:0] <= (last_addr&'h1ffffe)>>1;
      writeq_addr[writeq_fill][lds_bit]   <= ~znLDS_sync[2];
      writeq_addr[writeq_fill][uds_bit]   <= ~znUDS_sync[2];
      writeq_data[writeq_fill]       <= data_in;
      
      if (writeq_fill<max_fill-1)
        writeq_fill <= writeq_fill+1;
      else
        writeq_fill <= 0;
        
      state <= WAIT_WRITE2;
    end
  end else if (state == WAIT_WRITE2) begin
    dataout <= 0;
    if (znAS_sync[1]==1) state <= IDLE;
  end
  
  if ((state == IDLE && (!(zREAD_sync[1]==1 && zaddr>=ram_low && zaddr<ram_high) || znAS_sync[1]==1))
      || state == WAIT_WRITE2) begin
    if (fetching /*&& cmd_ready && (data_out_ready || fetch_x==0)*/) begin
      ram_data_buffer[fetch_x] <= ram_data_out[15:0];
      
      fetch_x <= fetch_x + 1;
      if (fetch_x > 800) begin
        fetching <= 0;
        fetch_x  <= 0;
        row_fetched <= 1; // row completely fetched
        burst_enable <= 0;
        // TODO burst terminate?
      end
      
      // catch up with counter if we're behind
      /*if (fetch_x < counter_x) begin
        fetch_x <= counter_x + 8;
      end*/
       
      // read window
      ram_addr  <= ((counter_y << 10) | fetch_x);
      if (!burst_enable) begin
        burst_enable <= 1;
        ram_enable <= 1; // fetch next burst
      end else begin
        ram_enable <= 0; // burst still running
      end
      
      ram_byte_enable <= 'b11;
      ram_write <= 0;
    end

    if (!fetching && cmd_ready && writeq_fill!=writeq_drain) begin
      // write window
      if (writeq_addr[writeq_drain][uds_bit] && !writeq_addr[writeq_drain][lds_bit])
        ram_byte_enable <= 'b10; // UDS
      else if (writeq_addr[writeq_drain][lds_bit] && !writeq_addr[writeq_drain][uds_bit])
        ram_byte_enable <= 'b01; // LDS
      else
        ram_byte_enable <= 'b11;
      
      ram_data_in <= (writeq_data[writeq_drain]);
      ram_addr    <= (writeq_addr[writeq_drain][q_msb:0]);   
      ram_write   <= 1;
      ram_enable  <= 1;
      wdelay <= 0;
      burst_enable <= 0;
      
      if (writeq_drain<max_fill-1)
        writeq_drain <= writeq_drain+1;
      else
        writeq_drain <= 0;
    end
    
    if (!fetching && (writeq_fill==writeq_drain)) begin
      if (wdelay==2) begin
        ram_enable <= 0;
        ram_write <= 0;
        ram_byte_enable <= 'b11;
        wdelay <= wdelay+1;
      end else if (wdelay<2) begin
        wdelay <= wdelay+1;
      end
    end
  end
  
  if (counter_x==0) begin
    row_fetched <= 0;
    fetch_x <= 0;
  end
end

reg[15:0] rgb = 'h0000;

always @(posedge vga_clk) begin
  if (counter_x >= h_max) begin
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
    rgb <= ram_data_buffer[counter_x];
    dvi_blank <= 0;
  end else begin
    dvi_blank <= 1;
    rgb <= 0;
  end

  blue_p[0] <= rgb[3];
  blue_p[1] <= rgb[4];
  blue_p[2] <= rgb[5];
  blue_p[3] <= rgb[5];
  blue_p[4] <= rgb[6];
  blue_p[5] <= rgb[6];
  blue_p[6] <= rgb[7];
  blue_p[7] <= rgb[7];
  
  green_p[0] <= rgb[13];
  green_p[1] <= rgb[14];
  green_p[2] <= rgb[15];
  green_p[3] <= rgb[0];
  green_p[4] <= rgb[1];
  green_p[5] <= rgb[1];
  green_p[6] <= rgb[2];
  green_p[7] <= rgb[2];
  
  red_p[0] <= rgb[8];
  red_p[1] <= rgb[9];
  red_p[2] <= rgb[10];
  red_p[3] <= rgb[10];
  red_p[4] <= rgb[11];  
  red_p[5] <= rgb[11];
  red_p[6] <= rgb[12];
  red_p[7] <= rgb[12];

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
      else begin
        if (counter_x>799)
          rgb <= 0;
        
        /*else if (counter_x<rec_depth) begin
          if (counter_y>=100 && counter_y<=145)
            rgb <= (rec_addr[counter_x][(counter_y-100)>>1])?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=200 && counter_y<=231)
            rgb <= (rec_data[counter_x][(counter_y-200)>>1])?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=300 && counter_y<=305)
            rgb <= rec_as[counter_x]?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=306 && counter_y<=310)
            rgb <= rec_uds[counter_x]?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=311 && counter_y<=315)
            rgb <= rec_lds[counter_x]?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=316 && counter_y<=320)
            rgb <= rec_doe[counter_x]?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else if (counter_y>=321 && counter_y<=325)
            rgb <= rec_read[counter_x]?(trigger_idx==counter_x?'hff00:'hffff):'h0000;
          else
            rgb <= ram_data_buffer[counter_x];*/
        else rgb <= ram_data_buffer[counter_x];
          
        /*else
          rgb <= ram_data_buffer[counter_x];*/
      end

end

endmodule
