`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
// SDRAM_controller_v.v
//
// Copyright (C) 2014  Mike Field
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
////////////////////////////////////////////////////////////////////////////////////
//
// Description:    Simple SDRAM controller for a Micron 48LC16M16A2-7E
//                 or Micron 48LC4M16A2-7E @ 100MHz      
// Revision: 
// Revision 0.1 - Initial verilog version
//
// Worst case performance (single accesses to different rows or banks) is: 
// Writes 16 cycles = 6,250,000 writes/sec = 25.0MB/s (excluding refresh overhead)
// Reads  17 cycles = 5,882,352 reads/sec  = 23.5MB/s (excluding refresh overhead)
//
// For 1:1 mixed reads and writes into the same row it is around 88MB/s 
// For reads or wries to the same it is can be as high as 184MB/s 
////////////////////////////////////////////////////////////////////////////////////
module SDRAM_Controller_v (
                           clk,   reset, idle,
                           // command and write port
                           cmd_ready, cmd_enable, cmd_wr, cmd_byte_enable, cmd_address, cmd_data_in, cmd_data_in_next,
                           // Read data port
                           data_out, data_out_ready, data_out_queue_empty, burst_size,
                           // SDRAM signals
                           SDRAM_CLK,  SDRAM_CKE,  SDRAM_CS,   SDRAM_RAS,  SDRAM_CAS,
                           SDRAM_WE,   SDRAM_DQM,  SDRAM_ADDR, SDRAM_BA,   SDRAM_DATA
                           );
  parameter sdram_column_bits    = 9;     // 
  parameter sdram_row_bits       = 13;
  parameter sdram_address_width  = 24;    // zzz
  parameter sdram_startup_cycles = 10100; // -- 100us, plus a little more, @ 100MHz
  parameter cycles_per_refresh   = 3000;  // (64000*100)/4196-1 Calced as  (64ms @ 100MHz)/ 4196 rows
  
  input  clk;
  input  reset;
  output cmd_ready;
  output idle;
  input  cmd_enable;
  input  cmd_wr;
  input  [sdram_address_width-1:0] cmd_address;
  input  [1:0]  cmd_byte_enable;
  input  [15:0] cmd_data_in;
  input  [15:0] cmd_data_in_next;
  input  [2:0]  burst_size;
  
  reg [3:0]  iob_command  = CMD_NOP;
  reg [12:0] iob_address  = 13'b0000000000000;
  reg [15:0] iob_data     = 16'b0000000000000000;
  reg [15:0] iob_data_next= 16'b0000000000000000;
  reg [1:0]  iob_dqm      = 2'b00;
  reg iob_cke             = 1'b0;
  reg [1:0]  iob_bank     = 2'b00;
  reg [15:0] data_out_reg;
  
  output [15:0] data_out;    assign data_out       = data_out_reg;

  reg data_out_ready_reg;
  output data_out_ready;     assign data_out_ready = data_out_ready_reg;
  reg data_out_queue_empty_reg = 1;
  output data_out_queue_empty; 
  assign data_out_queue_empty = data_out_queue_empty_reg;

  output SDRAM_CLK;          // Assigned by a primative
  output SDRAM_CKE;          assign SDRAM_CKE = iob_cke;
  output SDRAM_CS;           assign SDRAM_CS   = iob_command[3];
  output SDRAM_RAS;          assign SDRAM_RAS  = iob_command[2];
  output SDRAM_CAS;          assign SDRAM_CAS  = iob_command[1];
  output SDRAM_WE;           assign SDRAM_WE   = iob_command[0];
  output [1:0]  SDRAM_DQM;   assign SDRAM_DQM  = iob_dqm;
  output [12:0] SDRAM_ADDR;  assign SDRAM_ADDR = iob_address;
  output [1:0]  SDRAM_BA;    assign SDRAM_BA   = iob_bank;
  inout  [15:0] SDRAM_DATA;  // Assigned by a primitive

  // From page 37 of MT48LC16M16A2 datasheet
  // Name (Function)       CS# RAS# CAS# WE# DQM  Addr    Data
  // COMMAND INHIBIT (NOP)  H   X    X    X   X     X       X
  // NO OPERATION (NOP)     L   H    H    H   X     X       X
  // ACTIVE                 L   L    H    H   X  Bank/row   X
  // READ                   L   H    L    H  L/H Bank/col   X
  // WRITE                  L   H    L    L  L/H Bank/col Valid
  // BURST TERMINATE        L   H    H    L   X     X     Active
  // PRECHARGE              L   L    H    L   X   Code      X
  // AUTO REFRESH           L   L    L    H   X     X       X 
  // LOAD MODE REGISTER     L   L    L    L   X  Op-code    X 
  // Write enable           X   X    X    X   L     X     Active
  // Write inhibit          X   X    X    X   H     X     High-Z

  // -- Here are the commands mapped to constants   
  parameter CMD_UNSELECTED    = 4'b1000;
  parameter CMD_NOP           = 4'b0111;
  parameter CMD_ACTIVE        = 4'b0011;
  parameter CMD_READ          = 4'b0101;
  parameter CMD_WRITE         = 4'b0100;
  parameter CMD_TERMINATE     = 4'b0110;
  parameter CMD_PRECHARGE     = 4'b0010;
  parameter CMD_REFRESH       = 4'b0001;
  parameter CMD_LOAD_MODE_REG = 4'b0000;
  
  wire [12:0] MODE_REG;     // Reserved,    WBL,   TEST,   CAS Latency (2), BT,    Burst Length (3)
  assign      MODE_REG =        {3'b000,    1'b0,  2'b00,  3'b010,          1'b0,  burst_size};
  
  reg  [15:0] captured_data;
  wire [15:0] sdram_din;

  ///////////////////////////////
  // States for the FSM
  ///////////////////////////////
  parameter s_startup   = 5'b00000, s_idle_in_6 = 5'b00001, s_idle_in_5 = 5'b00010, s_idle_in_4 = 5'b00011;
  parameter s_idle_in_3 = 5'b00100, s_idle_in_2 = 5'b00101, s_idle_in_1 = 5'b00110, s_idle      = 5'b00111;
  parameter s_open_in_2 = 5'b01000, s_open_in_1 = 5'b01001, s_write_1   = 5'b01010, s_write_2   = 5'b01011;
  parameter s_write_3   = 5'b01100, s_read_1    = 5'b01101, s_read_2    = 5'b01110, s_read_3    = 5'b01111;
  parameter s_read_4    = 5'b10000, s_precharge = 5'b10001;
  parameter s_burst_read= 5'b10010;
  parameter s_open_in_3 = 5'b10011;
  parameter s_open_in_4 = 5'b10100;
  parameter s_open_in_5 = 5'b10101;
  parameter s_open_in_6 = 5'b10110;
  parameter s_open_in_7 = 5'b10111;
  parameter s_open_in_8 = 5'b11000;
  reg [4:0] state = s_startup;

  assign idle = (state == s_idle);
  
  // dual purpose counter, it counts up during the startup phase, then is used to trigger refreshes.
  parameter startup_refresh_max   = 14'b11111111111111;
  reg  [13:0] startup_refresh_count = startup_refresh_max-sdram_startup_cycles;

  // The incoming address is split into these three values
  wire [12:0] addr_row;
  wire [12:0] addr_col;
  wire [1:0]  addr_bank;

  // shift register to hold the DQM bits
  //parameter dqm_sr_high = 1;
  //reg [dqm_sr_high:0] dqm_sr = 2'b11; // an extra two bits in case CAS=3
  
  // signals to hold the requested transaction before it is completed
  reg save_wr                  = 1'b0; 
  reg [sdram_row_bits-1:0] save_row          = 13'b0000000000000;
  reg [1:0]  save_bank         = 2'b00;
  reg [sdram_row_bits-1:0] save_col          = 13'b0000000000000;
  reg [15:0] save_data_in      = 16'b0000000000000000;
  reg [15:0] save_data_in_next = 16'b0000000000000000;
  reg [1:0]  save_byte_enable  = 2'b00;
  
  // control when new transactions are accepted 
  reg ready_for_new    = 1'b0;
  reg got_transaction  = 1'b0;
  
  // signal to control the Hi-Z state of the DQ bus
  reg iob_dq_hiz = 1'b0;
  
  // shift register for when to read the data off of the bus
  parameter data_ready_delay_high = 3; // can be a bit faster in simulation, but not in real life
  reg [data_ready_delay_high:0] data_ready_delay;
  // reg [3:0] data_ready_delay; // (for < 60Mhz)
  
  // 9 10 11 12 13 14 15 16 17 18 29 20 21
  
  // bit indexes used when splitting the address into row/colum/bank.
  parameter start_of_col  = 0;
  parameter end_of_col    = sdram_column_bits-1;
  parameter start_of_row  = sdram_column_bits; // 9
  parameter end_of_row    = sdram_column_bits+sdram_row_bits-1; // 9+13-1 = 21
  parameter start_of_bank = sdram_address_width-2;
  parameter end_of_bank   = sdram_address_width-1;
  parameter prefresh_cmd  = 10;

  // tell the outside world when we can accept a new transaction;
  assign cmd_ready = ready_for_new;
  //--------------------------------------------------------------------------
  // Seperate the address into row / bank / address
  //--------------------------------------------------------------------------
  assign addr_row[end_of_row-start_of_row:0] = cmd_address[end_of_row:start_of_row];
  assign addr_bank                           = cmd_address[end_of_bank:start_of_bank];
  
  assign addr_col[12:sdram_column_bits]      = 4'b00;
  assign addr_col[sdram_column_bits-1:0]     = cmd_address[end_of_col:start_of_col];
  
  //-----------------------------------------------------------
  // Forward the SDRAM clock to the SDRAM chip - 180 degress 
  // out of phase with the control signals (ensuring setup and holdup times
  //-----------------------------------------------------------
  ODDR2 #(
          .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
          .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
          .SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
          ) ODDR2_inst (
                        .Q(SDRAM_CLK), .CE(1'b1), 
                        .C0(clk),  .C1(~clk), 
                        .D0(1'b0), .D1(1'b1),
                        .R(1'b0),  .S(1'b0)
                        );

  assign SDRAM_DATA = (iob_dq_hiz?'hzzzz:iob_data);

  reg can_back_to_back = 0;
  reg [2:0] burst_old = 0;

  always @(negedge clk) 
    begin
      captured_data <= SDRAM_DATA;
    end
      
  always @(posedge clk)
    begin
      startup_refresh_count <= startup_refresh_count+1'b1;
      
      //-- It we are ready for a new transaction and one is being presented
      //-- then accept it. Also remember what we are reading or writing,
      //-- and if it can be back-to-backed with the last transaction
      if (ready_for_new == 1'b1 && cmd_enable == 1'b1) begin
        if (save_bank == addr_bank && save_row == addr_row) 
          can_back_to_back <= 1'b1;
        else
          can_back_to_back <= 1'b0;
        save_row         <= addr_row;
        save_bank        <= addr_bank;
        save_col         <= addr_col;
        save_wr          <= cmd_wr; 
        save_data_in     <= cmd_data_in;
        save_data_in_next<= cmd_data_in_next;
        save_byte_enable <= cmd_byte_enable;
        got_transaction  <= 1'b1;
        ready_for_new    <= 1'b0;
      end else if (cmd_enable == 1'b0) begin
        //got_transaction  <= 1'b0;
        //ready_for_new    <= 1'b1;
      end
      
      // empty read queue if switched off
      //if (cmd_enable == 0) begin
      //  data_ready_delay <= 0;
      //end

      if (data_ready_delay[0] == 1'b1) begin
        data_out_reg       <= captured_data;
        data_out_ready_reg <= 1'b1;
      end else begin
        data_out_ready_reg <= 1'b0;
      end
      
      // no more bits in the queue?
      if (data_ready_delay == 0)
        data_out_queue_empty_reg <= 1;
      else
        data_out_queue_empty_reg <= 0;
      
      //-- update shift registers used to choose when to present data to/from memory
      data_ready_delay <= {1'b0, data_ready_delay[data_ready_delay_high:1]};
      
      case(state) 
        s_startup: begin
          //------------------------------------------------------------------------
          //-- This is the initial startup state, where we wait for at least 100us
          //-- before starting the start sequence
          //-- 
          //-- The initialisation is sequence is 
          //--  * de-assert SDRAM_CKE
          //--  * 100us wait, 
          //--  * assert SDRAM_CKE
          //--  * wait at least one cycle, 
          //--  * PRECHARGE
          //--  * wait 2 cycles
          //--  * REFRESH, 
          //--  * tREF wait
          //--  * REFRESH, 
          //--  * tREF wait 
          //--  * LOAD_MODE_REG 
          //--  * 2 cycles wait
          //------------------------------------------------------------------------
          iob_cke <= 1'b1;
          
          // All the commands during the startup are NOPS, except these
          /*if (startup_refresh_count == startup_refresh_max-31) begin
            // ensure all rows are closed
            iob_command     <= CMD_PRECHARGE;
            iob_address[prefresh_cmd] <= 1'b1;  // all banks
            iob_bank        <= 2'b00;
          end
          else if (startup_refresh_count == startup_refresh_max-23) begin
            // these refreshes need to be at least tREF (66ns) apart
            iob_command     <= CMD_REFRESH;
          end
          else if (startup_refresh_count == startup_refresh_max-15) begin
            iob_command     <= CMD_REFRESH;
          end else if (startup_refresh_count == startup_refresh_max-7) begin
            // Now load the mode register
            iob_command     <= CMD_LOAD_MODE_REG;
            iob_address     <= MODE_REG;
          end
          else if (startup_refresh_count == 1'b0) begin*/
            state           <= s_idle;
            ready_for_new   <= 1'b1;
            got_transaction <= 1'b0;
            startup_refresh_count <= 2048 - cycles_per_refresh+1;
          //end
        end
        s_idle_in_6: begin
          iob_command     <= CMD_NOP;
          state <= s_idle_in_5;
        end
        s_idle_in_5: state <= s_idle_in_4;
        s_idle_in_4: begin
          iob_command     <= CMD_NOP;
          state <= s_idle_in_3;
        end
        s_idle_in_3: state <= s_idle_in_2;
        s_idle_in_2: begin
          iob_command     <= CMD_NOP;
          state <= s_idle_in_1;
        end
        s_idle_in_1: state <= s_idle;

        s_idle: begin
          if (burst_size != burst_old) begin
            // switch burst off
            iob_command     <= CMD_LOAD_MODE_REG;
            iob_address     <= MODE_REG;
            state <= s_idle_in_2;
            burst_old <= burst_size;
          end else if (got_transaction == 1'b1) begin
            state       <= s_open_in_2;
            
            iob_command <= CMD_ACTIVE;
            iob_address <= save_row;
            iob_bank    <= save_bank;
            ready_for_new   <= 1'b0;
          end else begin
            iob_command     <= CMD_NOP;
            iob_address     <= 13'b0000000000000;
            iob_bank        <= 2'b00;
          end
        end
        
        s_open_in_8: state <= s_open_in_7;
        s_open_in_7: state <= s_open_in_6;
        s_open_in_6: state <= s_open_in_5;
        s_open_in_5: state <= s_open_in_4;
        s_open_in_4: state <= s_open_in_3;
        s_open_in_3: state <= s_open_in_2;
        
        s_open_in_2: begin
          // activate must be followed by NOP
          iob_command     <= CMD_NOP;
          if (save_wr == 1'b1)
            iob_dq_hiz  <= 1'b0;
          else
            iob_dq_hiz  <= 1'b1;
          
          state <= s_open_in_1;
        end
        
        s_open_in_1: begin 
          // still waiting for row to open
          if (save_wr == 1'b1) begin
            // write
            state       <= s_write_1;
            //iob_dq_hiz  <= 1'b0;
            iob_data    <= save_data_in[15:0];
          end else begin
            // read
            //iob_dq_hiz  <= 1'b1;
            state       <= s_read_1;
          end
          ready_for_new   <= 1'b1; 
          got_transaction <= 1'b0;
        end
        
        s_burst_read: begin
          if (burst_size==0 || save_col=='h1ff || !cmd_enable) begin
            iob_command <= CMD_TERMINATE;
            state <=  s_precharge;
            ready_for_new   <= 1'b1;
            got_transaction <= 1'b0;
          end else begin
            //iob_dqm     <= 2'b00;
            ready_for_new <= 1'b1;
            iob_command <= CMD_NOP;
            data_ready_delay[data_ready_delay_high] <= 1'b1;
          end
        end
        s_read_1: begin
          iob_command     <= CMD_READ;
          iob_address     <= save_col; 
          iob_bank        <= save_bank;
          iob_address[prefresh_cmd] <= 1'b0;
          iob_dqm     <= 2'b00;
          
          if (burst_old>1) begin
            ready_for_new <= 1'b1;
            state <= s_burst_read;
            data_ready_delay[data_ready_delay_high]   <= 1'b1;
          end else begin
            data_ready_delay[data_ready_delay_high]   <= 1'b1;
            state <= s_read_2;
          end
        end   
        s_read_2: begin
          //iob_command <= CMD_NOP;
          state <= s_read_3;
          if (got_transaction == 1'b1 && can_back_to_back == 1'b1) begin
            if (save_wr == 1'b0) begin 
              // read
              state           <= s_read_1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;
            end
          end
        end
        s_read_3: begin
          //iob_command <= CMD_NOP;
          state <= s_read_4;
          if (got_transaction == 1'b1 && can_back_to_back == 1'b1) begin
            if (save_wr == 1'b0) begin
              // read 
              state           <= s_read_1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;
            end
          end
        end

        s_read_4: begin
          //iob_command <= CMD_NOP;
          state <= s_precharge;
          //-- can we do back-to-back read?
          if (got_transaction == 1'b1 && can_back_to_back == 1'b1) begin
            if (save_wr == 1'b0) begin 
              state           <= s_read_1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;
            end
            else
              state <= s_open_in_2;
          end
        end
        //------------------------------------------------------------------
        // -- Processing the write transaction
        //-------------------------------------------------------------------
        s_write_1: begin
          state <= s_write_2;
          
          iob_command               <= CMD_WRITE;
          iob_address               <= save_col; 
          iob_address[prefresh_cmd] <= 1'b0;
          iob_bank                  <= save_bank;
          iob_dqm                   <= ~ save_byte_enable[1:0];
          iob_data                  <= save_data_in[15:0];
          iob_data_next             <= save_data_in_next[15:0];
        end
        s_write_2: begin
          state           <= s_write_3;
          
          if (burst_old==3'b001) begin
            iob_data        <= iob_data_next;
            iob_command     <= CMD_NOP;
          end
          
          // can we do a back-to-back write?
          if (got_transaction == 1'b1 && can_back_to_back == 1'b1) begin
            if (save_wr == 1'b1) begin
              // back-to-back write?
              state           <= s_write_1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;
            end
            // Although it looks right in simulation you can't go write-to-read 
            // here due to bus contention, as iob_dq_hiz takes a few ns.
          end
        end
        s_write_3: begin
          //iob_command     <= CMD_NOP;

          if (burst_old==3'b001) begin
            iob_command     <= CMD_TERMINATE;
          end
          
          // must wait tRDL, hence the extra idle state
          //-- back to back transaction?
          if (got_transaction == 1'b1 && can_back_to_back == 1'b1 && save_wr==1'b1) begin
            //if (save_wr == 1'b1) begin
              // back-to-back write?
              state           <= s_write_1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;
            //end
            /*else begin
              // write-to-read switch?
              state           <= s_read_1;
              iob_dq_hiz      <= 1'b1;
              ready_for_new   <= 1'b1;
              got_transaction <= 1'b0;                  
            end*/
          end else begin
            state              <= s_precharge;
          end
        end
        //-- Closing the row off (this closes all banks)
        s_precharge: begin
          iob_dq_hiz      <= 1'b1;
          state                     <= s_idle_in_4;
          iob_command               <= CMD_PRECHARGE;
          iob_address[prefresh_cmd] <= 1'b0;
        end
        //-- We should never get here, but if we do then reset the memory
        default: begin 
          state                 <= s_startup;
          ready_for_new         <= 1'b0;
          //startup_refresh_count <= startup_refresh_max-sdram_startup_cycles;
        end
      endcase

      if (reset == 1'b1) begin  // Sync reset
        state                 <= s_startup;
        ready_for_new         <= 1'b0;
        startup_refresh_count <= startup_refresh_max-sdram_startup_cycles;
      end
    end      
endmodule
