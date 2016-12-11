--**********************************************************************
-- Copyright (c) 2012-2014 by XESS Corp <http://www.xess.com>.
-- All rights reserved.
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 3.0 of the License, or (at your option) any later version.
-- 
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library.  If not, see 
-- <http://www.gnu.org/licenses/>.
--**********************************************************************

--*********************************************************************
-- SD MEMORY CARD INTERFACE
--
-- Reads/writes a single or multiple blocks of data to/from an SD Flash card.
-- 
-- Based on XESS by by Steven J. Merrifield, June 2008:
-- http : //stevenmerrifield.com/tools/sd.vhd
-- 
-- Most of what I learned about interfacing to SD/SDHC cards came from here:
-- http://elm-chan.org/docs/mmc/mmc_e.html
--
-- OPERATION
--
--     Set-up:
--         First of all, you have to give the controller a clock signal on the clk_i 
--         input with a higher frequency than the serial clock sent to the SD card 
--         through the sclk_o output. You can set generic parameters for the 
--         controller to tell it the master clock frequency (100 MHz), the SCLK 
--         frequency for initialization (400 KHz), the SCLK frequency for normal 
--         operation (25 MHz), the size of data sectors in the Flash memory (512 bytes),
--         and the type of card (either SD or SDHC). I typically use a 100 MHz 
--         clock if I'm running an SD card with a 25 Mbps serial data stream. 
--       
--     Initialize it:
--         Pulsing the reset_i input high and then bringing it low again will make 
--         the controller initialize the SD card so it will XESS in SPI mode. 
--         Basically, it sends the card the commands CMD0, CMD8 and then ACMD41 (which
--         is CMD55 followed by CMD41). The busy_o output will be high during the 
--         initialization and will go low once it is done. 
--        
--         After the initialization command sequence, the SD card will send back an R1
--         response byte. If only the IDLE bit of the R1 response is set, then the 
--         controller will repeatedly re-try the ACMD41 command while busy_o remains 
--         high. 
--        
--         If any other bit of the R1 response is set, then an error occurred. The 
--         controller will stall, lower busy_o, and output the R1 response code on the
--         error_o bus. You'll have to pulse reset_i to unfreeze the controller. 
--     
--         If the R1 response is all zeroes (i.e., no errors occurred during the 
--         initialization), then the controller will lower busy_o and wait for a 
--         read or write operation from the host. The controller will only accept new
--         operations when busy_o is low.
--     
--     Write data:
--         To write a data block to the SD card, the address of a block is placed 
--         on the addr_i input bus and the wr_i input is raised. The address and 
--         write strobe can be removed once busy_o goes high to indicate the write 
--         operation is underway. The data to be written to the SD card is passed as 
--         follows: 
--     
--         1. The controller requests a byte of data by raising the hndShk_o output.
--         2. The host applies the next byte to the data_i input bus and raises the 
--            hndShk_i input.
--         3. The controller accepts the byte and lowers the hndShk_o output.
--         4. The host lowers the hndShk_i input.
--     
--         This sequence of steps is repeated until all BLOCK_SIZE_G bytes of the 
--         data block are passed from the host to the controller. Once all the data 
--         is passed, the sector on the SD card will be written and the busy_o output 
--         will be lowered. 
--     
--     Read data:
--         To read a block of data from the SD card, the address of a block is 
--         placed on the addr_i input bus and the rd_i input is raised. The address 
--         and read strobe can be removed once busy_o goes high to indicate the read 
--         operation is underway. The data read from the SD card is passed to the 
--         host as follows: 
--     
--         1. The controller raises the hndShk_o output when the next data byte is available.
--         2. The host reads the byte from the data_o output bus and raises the hndShk_i input.
--         3. The controller lowers the hndShk_o output.
--         4. The host lowers the hndShk_i input.
--     
--         This sequence of steps is repeated until all BLOCK_SIZE_G bytes of the 
--         data block are passed from the controller to the host. Once all the data 
--         is read, the busy_o output will be lowered.
--     
--     Handle errors:
--         If an error is detected during either a read or write operation, then the
--         controller will stall, lower busy_o, and output an error code on the 
--         error_o bus. You'll have to pulse reset_i to unfreeze the controller. That 
--         may seem a bit excessive, but it does guarantee that you can't ignore any 
--         errors that occur.
--
-- TODO:
--
--     * Implement multi-block read and write commands.
--     * Allow host to send/receive SPI commands/data directly to
--       the SD card through the controller.
-- *********************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package common is
  type CardType_t is (SD_CARD_E, SDHC_CARD_E);  -- Define the different types of SD cards.
  constant YES  : std_logic := '1';
  constant NO   : std_logic := '0';
  constant HI   : std_logic := '1';
  constant LO   : std_logic := '0';
  constant ONE  : std_logic := '1';
  constant ZERO : std_logic := '0';
  constant HIZ  : std_logic := 'Z';
  function IntMax(a : in integer; b : in integer) return integer;
end common;

package body common is
  -- Find the maximum of two integers.
  function IntMax(a : in integer; b : in integer) return integer is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
    return a;
  end function IntMax;
end package body;

library IEEE, XESS;
use IEEE.math_real.all;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--library IEEE, XESS;
--use IEEE.math_real.all;
--use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
use Work.common.all;

entity SdCardCtrl is

  generic (
    FREQ_G          : real       := 150.0;     -- Master clock frequency (MHz).
    INIT_SPI_FREQ_G : real       := 0.25;  -- Slow SPI clock freq. during initialization (MHz).
    SPI_FREQ_G      : real       := 10.0;  -- Operational SPI freq. to the SD card (MHz).
    BLOCK_SIZE_G    : natural    := 512;  -- Number of bytes in an SD card block or sector.
    CARD_TYPE_G     : CardType_t := SDHC_CARD_E  -- Type of SD card connected to this controller.
    );
    
  port (
    -- Host-side interface signals.
    clk_i      : in  std_logic;         -- Master clock.
    reset_i    : in  std_logic                     := NO;  -- active-high, synchronous  reset.
    rd_i       : in  std_logic                     := NO;  -- active-high read block request.
    wr_i       : in  std_logic                     := NO;  -- active-high write block request.
    continue_i : in  std_logic                     := NO;  -- If true, inc address and continue R/W.
    addr_i     : in  std_logic_vector(31 downto 0) := x"00000000";  -- Block address.
    data_i     : in  std_logic_vector(7 downto 0)  := x"00";  -- Data to write to block.
    data_o     : out std_logic_vector(7 downto 0)  := x"00";  -- Data read from block.
    busy_o     : out std_logic;  -- High when controller is busy performing some operation.
    hndShk_i   : in  std_logic;  -- High when host has data to give or has taken data.
    hndShk_o   : out std_logic;  -- High when controller has taken data or has data to give.
    error_o    : out std_logic_vector(15 downto 0) := (others => NO);
    -- I/O signals to the external SD card.
    cs_bo      : out std_logic                     := HI;  -- Active-low chip-select.
    sclk_o     : out std_logic                     := LO;  -- Serial clock to SD card.
    mosi_o     : out std_logic                     := HI;  -- Serial data output to SD card.
    miso_i     : in  std_logic                     := ZERO;  -- Serial data input from SD card.
    clkdiv_o   : out std_logic_vector(15 downto 0) := (others => NO)
    );
end entity;



architecture arch of SdCardCtrl is

  signal sclk_r   : std_logic := ZERO;  -- Register output drives SD card clock.
  signal hndShk_r : std_logic := NO;  -- Register output drives handshake output to host.

begin
  
  process(clk_i)  -- FSM process for the SD card controller.

    type FsmState_t is (    -- States of the SD card controller FSM.
      START_INIT,  -- Send initialization clock pulses to the deselected SD card.    
      SEND_CMD0,                        -- Put the SD card in the IDLE state.
      CHK_CMD0_RESPONSE,    -- Check card's R1 response to the CMD0.
      SEND_CMD8,   -- This command is needed to initialize SDHC cards.
      GET_CMD8_RESPONSE,                -- Get the R7 response to CMD8.
      SEND_CMD55,                       -- Send CMD55 to the SD card. 
      SEND_CMD41,                       -- Send CMD41 to the SD card.
      CHK_ACMD41_RESPONSE,  -- Check if the SD card has left the IDLE state.     
      WAIT_FOR_HOST_RW,  -- Wait for the host to issue a read or write command.
      RD_BLK,    -- Read a block of data from the SD card.
      WR_BLK,    -- Write a block of data to the SD card.
      WR_WAIT,   -- Wait for SD card to finish writing the data block.
      START_TX,                         -- Start sending command/data.
      TX_BITS,   -- Shift out remaining command/data bits.
      GET_CMD_RESPONSE,  -- Get the R1 response of the SD card to a command.
      RX_BITS,   -- Receive response/data from the SD card.
      DESELECT,  -- De-select the SD card and send some clock pulses (Must enter with sclk at zero.)
      PULSE_SCLK,  -- Issue some clock pulses. (Must enter with sclk at zero.)
      REPORT_ERROR                      -- Report error and stall until reset.
      );
    variable state_v    : FsmState_t := START_INIT;  -- Current state of the FSM.
    variable rtnState_v : FsmState_t;  -- State FSM returns to when FSM subroutine completes.

    -- Timing constants based on the master clock frequency and the SPI SCLK frequencies.
    constant CLKS_PER_INIT_SCLK_C      : real    := FREQ_G / INIT_SPI_FREQ_G;
    constant CLKS_PER_SCLK_C           : real    := FREQ_G / SPI_FREQ_G;
    constant MAX_CLKS_PER_SCLK_C       : real    := realmax(CLKS_PER_INIT_SCLK_C, CLKS_PER_SCLK_C);
    constant MAX_CLKS_PER_SCLK_PHASE_C : natural := integer(round(MAX_CLKS_PER_SCLK_C / 2.0));
    constant INIT_SCLK_PHASE_PERIOD_C  : natural := integer(round(CLKS_PER_INIT_SCLK_C / 2.0));
    constant SCLK_PHASE_PERIOD_C       : natural := integer(round(CLKS_PER_SCLK_C / 2.0));
    constant DELAY_BETWEEN_BLOCK_RW_C  : natural := SCLK_PHASE_PERIOD_C;

    -- Registers for generating slow SPI SCLK from the faster master clock.
    variable clkDivider_v     : natural range 0 to MAX_CLKS_PER_SCLK_PHASE_C;  -- Holds the SCLK period.
    variable sclkPhaseTimer_v : natural range 0 to MAX_CLKS_PER_SCLK_PHASE_C;  -- Counts down to zero, then SCLK toggles.

    constant NUM_INIT_CLKS_C : natural := 160;  -- Number of initialization clocks to SD card.
    variable bitCnt_v        : natural range 0 to NUM_INIT_CLKS_C;  -- Tx/Rx bit counter.

    constant CRC_SZ_C    : natural := 2;  -- Number of CRC bytes for read/write blocks.
    -- When reading blocks of data, get 0xFE + [DATA_BLOCK] + [CRC].
    constant RD_BLK_SZ_C : natural := 1 + BLOCK_SIZE_G + CRC_SZ_C;
    -- When writing blocks of data, send 0xFF + 0xFE + [DATA BLOCK] + [CRC] then receive response byte.
    constant WR_BLK_SZ_C : natural := 1 + 1 + BLOCK_SIZE_G + CRC_SZ_C + 1;
    variable byteCnt_v   : natural range 0 to IntMax(WR_BLK_SZ_C, RD_BLK_SZ_C);  -- Tx/Rx byte counter.

    -- Command bytes for various SD card operations.
    subtype Cmd_t is std_logic_vector(7 downto 0);
    constant CMD0_C          : Cmd_t := std_logic_vector(to_unsigned(16#40# + 0, Cmd_t'length));
    constant CMD8_C          : Cmd_t := std_logic_vector(to_unsigned(16#40# + 8, Cmd_t'length));
    constant CMD55_C         : Cmd_t := std_logic_vector(to_unsigned(16#40# + 55, Cmd_t'length));
    constant CMD41_C         : Cmd_t := std_logic_vector(to_unsigned(16#40# + 41, Cmd_t'length));
    constant READ_BLK_CMD_C  : Cmd_t := std_logic_vector(to_unsigned(16#40# + 17, Cmd_t'length));
    constant WRITE_BLK_CMD_C : Cmd_t := std_logic_vector(to_unsigned(16#40# + 24, Cmd_t'length));

    -- Except for CMD0 and CMD8, SD card ops don't need a CRC, so use a fake one for that slot in the command.
    constant FAKE_CRC_C : std_logic_vector(7 downto 0) := x"FF";

    variable addr_v : unsigned(addr_i'range);  -- Address of current block for R/W operations.

    -- Maximum Tx to SD card consists of command + address + CRC. Data Tx is just a single byte.
    variable tx_v : std_logic_vector(CMD0_C'length + addr_v'length + FAKE_CRC_C'length - 1 downto 0);  -- Data/command to SD card.
    alias txCmd_v is tx_v;              -- Command transmission shift register.
    alias txData_v is tx_v(tx_v'high downto tx_v'high - data_i'length + 1);  -- Data byte transmission shift register.

    variable rx_v               : std_logic_vector(data_i'range);  -- Data/response byte received from SD card.
    -- Various response codes.
    subtype Response_t is std_logic_vector(rx_v'range);
    constant ACTIVE_NO_ERRORS_C : Response_t := "00000000";  -- Normal R1 code after initialization.
    constant IDLE_NO_ERRORS_C   : Response_t := "00000001";  -- Normal R1 code after CMD0.
    constant DATA_ACCEPTED_C    : Response_t := "---00101";  -- SD card accepts data block from host.
    constant DATA_REJ_CRC_C     : Response_t := "---01011";  -- SD card rejects data block from host due to CRC error.
    constant DATA_REJ_WERR_C    : Response_t := "---01101";  -- SD card rejects data block from host due to write error.
    -- Various tokens.
    subtype Token_t is std_logic_vector(rx_v'range);
    constant NO_TOKEN_C         : Token_t    := x"FF";  -- Received before the SD card responds to a block read command.
    constant START_TOKEN_C      : Token_t    := x"FE";  -- Starting byte preceding a data block.

    -- Flags that are set/cleared to affect the operation of the FSM.
    variable getCmdResponse_v : boolean;  -- When true, get R1 response to command sent to SD card.
    variable rtnData_v        : boolean;  -- When true, signal to host when a data byte arrives from SD card.
    variable doDeselect_v     : boolean;  -- When true, de-select SD card after a command is issued.
    
  begin
    if rising_edge(clk_i) then
    
      clkdiv_o <= std_logic_vector(to_unsigned(clkDivider_v,16));

      if reset_i = YES then             -- Perform a reset.
        state_v          := START_INIT;  -- Send the FSM to the initialization entry-point.
        sclkPhaseTimer_v := 0;  -- Don't delay the initialization right after reset.
        busy_o           <= YES;  -- Busy while the SD card interface is being initialized.

      elsif sclkPhaseTimer_v /= 0 then
        -- Setting the clock phase timer to a non-zero value delays any further actions
        -- and generates the slower SPI clock from the faster master clock.
        sclkPhaseTimer_v := sclkPhaseTimer_v - 1;

        -- Clock phase timer has reached zero, so check handshaking sync. between host and controller.

        -- Handshaking lets the host control the flow of data to/from the SD card controller.
        -- Handshaking between the SD card controller and the host proceeds as follows:
        --   1: Controller raises its handshake and waits.
        --   2: Host sees controller handshake and raises its handshake in acknowledgement.
        --   3: Controller sees host handshake acknowledgement and lowers its handshake.
        --   4: Host sees controller lower its handshake and removes its handshake.
        --
        -- Handshaking is bypassed when the controller FSM is initializing the SD card.
        
      elsif state_v /= START_INIT and hndShk_r = HI and hndShk_i = LO then
        null;            -- Waiting for the host to acknowledge handshake.
      elsif state_v /= START_INIT and hndShk_r = HI and hndShk_i = HI then
        txData_v := data_i;             -- Get any data passed from the host.
        hndShk_r <= LO;  -- The host acknowledged, so lower the controller handshake.
      elsif state_v /= START_INIT and hndShk_r = LO and hndShk_i = HI then
        null;            -- Waiting for the host to lower its handshake.
      elsif (state_v = START_INIT) or (hndShk_r = LO and hndShk_i = LO) then
        -- Both handshakes are low, so the controller operations can proceed.
        
        busy_o <= YES;  -- Busy by default. Only false when waiting for R/W from host or stalled by error.

        case state_v is
          
          when START_INIT =>  -- Deselect the SD card and send it a bunch of clock pulses with MOSI high.
            error_o          <= (others => ZERO);  -- Clear error flags.
            clkDivider_v     := INIT_SCLK_PHASE_PERIOD_C - 1;  -- Use slow SPI clock freq during init.
            sclkPhaseTimer_v := INIT_SCLK_PHASE_PERIOD_C - 1;  -- and set the duration of the next clock phase.
            sclk_r           <= LO;     -- Start with low clock to the SD card.
            hndShk_r         <= LO;     -- Initialize handshake signal.
            addr_v           := (others => ZERO);  -- Initialize address.
            rtnData_v        := false;  -- No data is returned to host during initialization.
            bitCnt_v         := NUM_INIT_CLKS_C;  -- Generate this many clock pulses.
            state_v          := DESELECT;  -- De-select the SD card and pulse SCLK.
            rtnState_v       := SEND_CMD0;  -- Then go to this state after the clock pulses are done.
            
          when SEND_CMD0 =>             -- Put the SD card in the IDLE state.
            cs_bo            <= LO;     -- Enable the SD card.
            txCmd_v          := CMD0_C & x"00000000" & x"95";  -- 0x95 is the correct CRC for this command.
            bitCnt_v         := txCmd_v'length;  -- Set bit counter to the size of the command.
            getCmdResponse_v := true;  -- Sending a command that generates a response.
            doDeselect_v     := true;  -- De-select SD card after this command finishes.
            state_v          := START_TX;  -- Go to FSM subroutine to send the command.
            rtnState_v       := CHK_CMD0_RESPONSE;  -- Then check the response to the command.
            
          when CHK_CMD0_RESPONSE =>  -- Check card's R1 response to the CMD0.
            if rx_v = IDLE_NO_ERRORS_C then
              state_v := SEND_CMD8;  -- Continue init if SD card is in IDLE state with no errors
            else
              state_v := SEND_CMD0;     -- Otherwise, try CMD0 again.
            end if;
            
          when SEND_CMD8 =>  -- This command is needed to initialize SDHC cards.
            cs_bo            <= LO;     -- Enable the SD card.
            txCmd_v          := CMD8_C & x"000001aa" & x"87";  -- 0x87 is the correct CRC for this command.
            bitCnt_v         := txCmd_v'length;  -- Set bit counter to the size of the command.
            getCmdResponse_v := true;  -- Sending a command that generates a response.
            doDeselect_v     := false;  -- Don't de-select, need to get the R7 response sent from the SD card.
            state_v          := START_TX;  -- Go to FSM subroutine to send the command.
            rtnState_v       := GET_CMD8_RESPONSE;  -- Then go to this state after the command is sent.
            
          when GET_CMD8_RESPONSE =>     -- Get the R7 response to CMD8.
            cs_bo            <= LO;  -- The SD card should already be enabled, but let's be explicit.
            bitCnt_v         := 31;     -- Four bytes (32 bits) in R7 response.
            getCmdResponse_v := false;  -- Not sending a command that generates a response.
            doDeselect_v     := true;  -- De-select card to end the command after getting the four bytes.
            state_v          := RX_BITS;  -- Go to FSM subroutine to get the R7 response.
            rtnState_v       := SEND_CMD55;  -- Then go here (we don't care what the actual R7 response is).

          when SEND_CMD55 =>  -- Send CMD55 as preamble of ACMD41 initialization command.
            cs_bo            <= LO;     -- Enable the SD card.
            txCmd_v          := CMD55_C & x"00000000" & FAKE_CRC_C;
            bitCnt_v         := txCmd_v'length;  -- Set bit counter to the size of the command.
            getCmdResponse_v := true;  -- Sending a command that generates a response.
            doDeselect_v     := true;  -- De-select SD card after this command finishes.
            state_v          := START_TX;  -- Go to FSM subroutine to send the command.
            rtnState_v       := SEND_CMD41;  -- Then go to this state after the command is sent.
            
          when SEND_CMD41 =>  -- Send the SD card the initialization command.
            cs_bo            <= LO;     -- Enable the SD card.
            txCmd_v          := CMD41_C & x"40000000" & FAKE_CRC_C;
            bitCnt_v         := txCmd_v'length;  -- Set bit counter to the size of the command.
            getCmdResponse_v := true;  -- Sending a command that generates a response.
            doDeselect_v     := true;  -- De-select SD card after this command finishes.
            state_v          := START_TX;  -- Go to FSM subroutine to send the command.
            rtnState_v       := CHK_ACMD41_RESPONSE;  -- Then check the response to the command.
            
          when CHK_ACMD41_RESPONSE =>
            -- The CMD55, CMD41 sequence should cause the SD card to leave the IDLE state
            -- and become ready for SPI read/write operations. If still IDLE, then repeat the CMD55, CMD41 sequence.
            -- If one of the R1 error flags is set, then report the error and stall.
            if rx_v = ACTIVE_NO_ERRORS_C then   -- Not IDLE, no errors.
              state_v := WAIT_FOR_HOST_RW;  -- Start processing R/W commands from the host.
            elsif rx_v = IDLE_NO_ERRORS_C then  -- Still IDLE but no errors. 
              state_v := SEND_CMD55;    -- Repeat the CMD55, CMD41 sequence.
            else                        -- Some error occurred.
              state_v := REPORT_ERROR;  -- Report the error and stall.
            end if;
            
          when WAIT_FOR_HOST_RW =>  -- Wait for the host to read or write a block of data from the SD card.
            clkDivider_v     := SCLK_PHASE_PERIOD_C - 1;  -- Set SPI clock frequency for normal operation.
            getCmdResponse_v := true;  -- Get R1 response to any commands issued to the SD card.
            if rd_i = YES then  -- send READ command and address to the SD card.
              cs_bo <= LO;              -- Enable the SD card.
              if continue_i = YES then  -- Multi-block read. Use stored address.
                if CARD_TYPE_G = SD_CARD_E then  -- SD cards use byte-addressing, 
                  addr_v := addr_v + BLOCK_SIZE_G;  -- so add block-size to get next block address.
                else                    -- SDHC cards use block-addressing,
                  addr_v := addr_v + 1;  -- so just increment current block address.
                end if;
                txCmd_v := READ_BLK_CMD_C & std_logic_vector(addr_v) & FAKE_CRC_C;
              else                      -- Single-block read.
                txCmd_v := READ_BLK_CMD_C & addr_i & FAKE_CRC_C;  -- Use address supplied by host.
                addr_v  := unsigned(addr_i);  -- Store address for multi-block operations.
              end if;
              bitCnt_v   := txCmd_v'length;  -- Set bit counter to the size of the command.
              byteCnt_v  := RD_BLK_SZ_C;
              state_v    := START_TX;  -- Go to FSM subroutine to send the command.
              rtnState_v := RD_BLK;  -- Then go to this state to read the data block.
            elsif wr_i = YES then  -- send WRITE command and address to the SD card.
              cs_bo <= LO;              -- Enable the SD card.
              if continue_i = YES then  -- Multi-block write. Use stored address.
                if CARD_TYPE_G = SD_CARD_E then  -- SD cards use byte-addressing, 
                  addr_v := addr_v + BLOCK_SIZE_G;  -- so add block-size to get next block address.
                else                    -- SDHC cards use block-addressing,
                  addr_v := addr_v + 1;  -- so just increment current block address.
                end if;
                txCmd_v := WRITE_BLK_CMD_C & std_logic_vector(addr_v) & FAKE_CRC_C;
              else                      -- Single-block write.
                txCmd_v := WRITE_BLK_CMD_C & addr_i & FAKE_CRC_C;  -- Use address supplied by host.
                addr_v  := unsigned(addr_i);  -- Store address for multi-block operations.
              end if;
              bitCnt_v   := txCmd_v'length;  -- Set bit counter to the size of the command.
              byteCnt_v  := WR_BLK_SZ_C;    -- Set number of bytes to write.
              state_v    := START_TX;  -- Go to this FSM subroutine to send the command ...
              rtnState_v := WR_BLK;  -- then go to this state to write the data block.
            else              -- Do nothing and wait for command from host.
              cs_bo   <= HI;            -- Deselect the SD card.
              busy_o  <= NO;  -- SD card interface is waiting for R/W from host, so it's not busy.
              state_v := WAIT_FOR_HOST_RW;  -- Keep waiting for command from host.
            end if;

          when RD_BLK =>          -- Read a block of data from the SD card.
            -- Some default values for these...
            rtnData_v  := false;  -- Data is only returned to host in one place.
            bitCnt_v   := rx_v'length - 1;   -- Receiving byte-sized data.
            state_v    := RX_BITS;      -- Call the bit receiver routine.
            rtnState_v := RD_BLK;   -- Return here when done receiving a byte.
            if byteCnt_v = RD_BLK_SZ_C then  -- Initial read to prime the pump.
              byteCnt_v := byteCnt_v - 1;
            elsif byteCnt_v = RD_BLK_SZ_C -1 then  -- Then look for the data block start token.
              if rx_v = NO_TOKEN_C then  -- Receiving 0xFF means the card hasn't responded yet. Keep trying.
                null;
              elsif rx_v = START_TOKEN_C then
                rtnData_v := true;  -- Found the start token, so now start returning data byes to the host.
                byteCnt_v := byteCnt_v - 1;
              else  -- Getting anything else means something strange has happened.
                state_v := REPORT_ERROR;
              end if;
            elsif byteCnt_v >= 3 then  -- Now bytes of data from the SD card are received.
              rtnData_v := true;        -- Return this data to the host.
              byteCnt_v := byteCnt_v - 1;
            elsif byteCnt_v = 2 then  -- Receive the 1st CRC byte at the end of the data block.
              rtnData_v := true;        -- Return this data to the host.
              byteCnt_v := byteCnt_v - 1;
            elsif byteCnt_v = 1 then    -- Receive the 2nd
              rtnData_v := true;        -- Return this data to the host.
              byteCnt_v := byteCnt_v - 1;
            else    -- Reading is done, so deselect the SD card.
              sclk_r     <= LO;
              bitCnt_v   := 2;
              state_v    := DESELECT;
              rtnState_v := WAIT_FOR_HOST_RW;
            end if;
            
          when WR_BLK =>             -- Write a block of data to the SD card.
            -- Some default values for these...
            getCmdResponse_v := false;  -- Sending data bytes so there's no command response from SD card.
            bitCnt_v         := txData_v'length;  -- Transmitting byte-sized data.
            state_v          := START_TX;  -- Call the bit transmitter routine.
            rtnState_v       := WR_BLK;  -- Return here when done transmitting a byte.
            if byteCnt_v = WR_BLK_SZ_C then
              txData_v := NO_TOKEN_C;  -- Hold MOSI high for one byte before data block goes out.
            elsif byteCnt_v = WR_BLK_SZ_C - 1 then     -- Send start token.
              txData_v := START_TOKEN_C;   -- Starting token for data block.
            elsif byteCnt_v >= 2 then   -- Now send bytes in the data block. (this was >= 4)
              hndShk_r <= HI;           -- Signal host to provide data.
            -- The transmit shift register is loaded with data from host in the handshaking section above.
            --elsif byteCnt_v = 3 or byteCnt_v = 2 then  -- Send two phony CRC bytes at end of packet.
            --  txData_v := FAKE_CRC_C;
            elsif byteCnt_v = 1 then
              bitCnt_v   := rx_v'length - 1;
              state_v    := RX_BITS;  -- Get response of SD card to the write operation.
              rtnState_v := WR_WAIT;
            else                        -- Check received response byte.
              if std_match(rx_v, DATA_ACCEPTED_C) then  -- Data block was accepted.
                state_v := WR_WAIT;  -- Wait for the SD card to finish writing the data into Flash.
              else                      -- Data block was rejected.
                error_o(15 downto 8) <= rx_v;
                state_v              := REPORT_ERROR;  -- Report the error.
              end if;
            end if;
            byteCnt_v := byteCnt_v - 1;
            
          when WR_WAIT =>  -- Wait for SD card to finish writing the data block.
            -- The SD card will pull MISO low while it is busy, and raise it when it is done.
            sclk_r           <= not sclk_r;    -- Toggle the SPI clock...
            sclkPhaseTimer_v := clkDivider_v;  -- and set the duration of the next clock phase.
            if sclk_r = HI and miso_i = HI then  -- Data block has been written, so deselect the SD card.
              bitCnt_v   := 2;
              state_v    := DESELECT;
              rtnState_v := WAIT_FOR_HOST_RW;
            end if;
            
          when START_TX =>
            -- Start sending command/data by lowering SCLK and outputing MSB of command/data
            -- so it has plenty of setup before the rising edge of SCLK.
            sclk_r           <= LO;  -- Lower the SCLK (although it should already be low).
            sclkPhaseTimer_v := clkDivider_v;  -- Set the duration of the low SCLK.
            mosi_o           <= tx_v(tx_v'high);  -- Output MSB of command/data.
            tx_v             := tx_v(tx_v'high-1 downto 0) & ONE;  -- Shift command/data register by one bit.
            bitCnt_v         := bitCnt_v - 1;  -- The first bit has been sent, so decrement bit counter.
            state_v          := TX_BITS;  -- Go here to shift out the rest of the command/data bits.
            
          when TX_BITS =>  -- Shift out remaining command/data bits and (possibly) get response from SD card.
            sclk_r           <= not sclk_r;    -- Toggle the SPI clock...
            sclkPhaseTimer_v := clkDivider_v;  -- and set the duration of the next clock phase.
            if sclk_r = HI then
              -- SCLK is going to be flipped from high to low, so output the next command/data bit
              -- so it can setup while SCLK is low.
              if bitCnt_v /= 0 then  -- Keep sending bits until the bit counter hits zero.
                mosi_o   <= tx_v(tx_v'high);
                tx_v     := tx_v(tx_v'high-1 downto 0) & ONE;
                bitCnt_v := bitCnt_v - 1;
              else
                if getCmdResponse_v then
                  state_v  := GET_CMD_RESPONSE;  -- Get a response to the command from the SD card.
                  bitCnt_v := Response_t'length - 1;  -- Length of the expected response.
                else
                  state_v          := rtnState_v;  -- Return to calling state (no need to get a response).
                  sclkPhaseTimer_v := 0;  -- Clear timer so next SPI op can begin ASAP with SCLK low.
                end if;
              end if;
            end if;

          when GET_CMD_RESPONSE =>  -- Get the response of the SD card to a command.
            if sclk_r = HI and miso_i = LO then  -- MISO will be held high by SD card until 1st bit of R1 response, which is 0.
              -- Shift in the MSB bit of the response.
              rx_v     := rx_v(rx_v'high-1 downto 0) & miso_i;
              bitCnt_v := bitCnt_v - 1;
              state_v  := RX_BITS;  -- Now receive the reset of the response.
            end if;
            sclk_r           <= not sclk_r;    -- Toggle the SPI clock...
            sclkPhaseTimer_v := clkDivider_v;  -- and set the duration of the next clock phase.

          when RX_BITS =>               -- Receive bits from the SD card.
            if sclk_r = HI then    -- Bits enter after the rising edge of SCLK.
              rx_v := rx_v(rx_v'high-1 downto 0) & miso_i;
              if bitCnt_v /= 0 then     -- More bits left to receive.
                bitCnt_v := bitCnt_v - 1;
              else                      -- Last bit has been received.
                if rtnData_v then       -- Send the received data to the host.
                  data_o   <= rx_v;     -- Output received data to the host.
                  hndShk_r <= HI;  -- Signal to the host that the data is ready.
                end if;
                if doDeselect_v then
                  bitCnt_v := 1;
                  state_v  := DESELECT;  -- De-select SD card before returning.
                else
                  state_v := rtnState_v;  -- Otherwise, return to calling state without de-selecting.
                end if;
              end if;
            end if;
            sclk_r           <= not sclk_r;    -- Toggle the SPI clock...
            sclkPhaseTimer_v := clkDivider_v;  -- and set the duration of the next clock phase.
            
          when DESELECT =>  -- De-select the SD card and send some clock pulses (Must enter with sclk at zero.)
            doDeselect_v     := false;  -- Once the de-select is done, clear the flag that caused it.
            cs_bo            <= HI;     -- De-select the SD card.
            mosi_o           <= HI;  -- Keep the data input of the SD card pulled high.
            state_v          := PULSE_SCLK;  -- Pulse the clock so the SD card will see the de-select.
            sclk_r           <= LO;  -- Clock is set low so the next rising edge will see the new CS and MOSI
            sclkPhaseTimer_v := clkDivider_v;  -- Set the duration of the next clock phase.
            
          when PULSE_SCLK =>  -- Issue some clock pulses. (Must enter with sclk at zero.)
            if sclk_r = HI then
              if bitCnt_v /= 0 then
                bitCnt_v := bitCnt_v - 1;
              else  -- Return to the calling routine when the pulse counter reaches zero.
                state_v := rtnState_v;
              end if;
            end if;
            sclk_r           <= not sclk_r;    -- Toggle the SPI clock...
            sclkPhaseTimer_v := clkDivider_v;  -- and set the duration of the next clock phase.
            
          when REPORT_ERROR =>  -- Report the error code and stall here until a reset occurs.
            error_o(rx_v'range) <= rx_v;  -- Output the SD card response as the error code.
            busy_o              <= NO;  -- Not busy.

          when others =>
            state_v := START_INIT;
        end case;
      end if;
    end if;
  end process;

  sclk_o   <= sclk_r;    -- Output the generated SPI clock for the SD card.
  hndShk_o <= hndShk_r;  -- Output the generated handshake to the host.
  
end architecture;

