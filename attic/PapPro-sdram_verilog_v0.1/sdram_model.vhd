----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:11:26 09/20/2013 
-- Design Name: 
-- Module Name:    sdram_model - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdram_model is
    Port ( CLK     : in  STD_LOGIC;
           CKE     : in  STD_LOGIC;
           CS_N    : in  STD_LOGIC;
           RAS_N   : in  STD_LOGIC;
           CAS_N   : in  STD_LOGIC;
           WE_N    : in  STD_LOGIC;
           BA      : in  STD_LOGIC_VECTOR (1 downto 0);
           DQM     : in  STD_LOGIC_VECTOR (1 downto 0);
           ADDR    : in  STD_LOGIC_VECTOR (12 downto 0);
           DQ      : inout  STD_LOGIC_VECTOR (15 downto 0));
end sdram_model;

architecture Behavioral of sdram_model is
   type decode is (unsel_c, lmr_c, ref_c, pre_c, act_c, wr_c, rd_c, term_c, nop_c);
   signal command : decode;
 
   signal dqm_sr : std_logic_vector(3 downto 0) := (others => '0');
   
   signal selected_bank : std_logic_vector( 1 downto 0);
   signal column        : std_logic_vector( 8 downto 0) := (others => '0');

   -- Only eight rows of four banks are modeled
   type   memory_array is array (0 to 8 * 512 * 4 -1 ) of std_logic_vector( 15 downto 0);
   type   row_array    is array (0 to       3) of std_logic_vector(2 downto 0);
   
   signal memory        : memory_array;
   signal active_row    : row_array;
   signal is_row_active : std_logic_vector(3 downto 0);
   signal mode_reg      : std_logic_vector(12 downto 0);
   signal data_delay1   : std_logic_vector(15 downto 0);
   signal data_delay2   : std_logic_vector(15 downto 0);
   signal data_delay3   : std_logic_vector(15 downto 0);
   signal addr_index    : STD_LOGIC_VECTOR(13 downto 0);         
   
   signal wr_mask       : std_logic_vector( 1 downto 0);
   signal wr_data       : std_logic_vector(15 downto 0);
   signal wr_burst      : std_logic_vector( 8 downto 0);
   signal rd_burst      : std_logic_vector( 9 downto 0);
   
begin
   addr_index <= active_row(to_integer(unsigned(selected_bank))) & selected_bank & column;

decode_proc: process(CS_N, RAS_N, CAS_N, WE_N)
   variable cmd : std_logic_vector(2 downto 0);
   begin
      if CS_N = '1' then
         command <= unsel_c;
      else
         cmd := RAS_N & CAS_N & WE_N;
         case cmd is 
            when "000"  => command <= LMR_c;
            when "001"  => command <= REF_c;
            when "010"  => command <= PRE_c;
            when "011"  => command <= ACT_c;
            when "100"  => command <= WR_c;
            when "101"  => command <= RD_c;
            when "110"  => command <= TERM_c;
            when others => command <= NOP_c;         
         end case;
      end if;
   end process;
 
data_process : process(clk)
   begin
      if rising_edge(clk) then
        
         -- this implements the data masks, gets updated when a read command is sent
         rd_burst(8 downto 0) <= rd_burst(9 downto 1);
         column <= std_logic_vector(unsigned(column)+1);
         
         wr_burst(7 downto 0) <= wr_burst(8 downto 1);

         -- Process any pending writes
         if wr_burst(0) = '1' and wr_mask(0) = '1' then
            memory(to_integer(unsigned(addr_index)))(7 downto 0) <= wr_data(7 downto 0);
         end if;
         if wr_burst(0) = '1' and wr_mask(1) = '1' then
            memory(to_integer(unsigned(addr_index)))(15 downto 8) <= wr_data(15 downto 8);
         end if;            
         wr_data       <= dq;

         -- default is not to write
         wr_mask <= "00";
         if command = wr_c then
            rd_burst <= (others => '0');
            column        <= addr(8 downto 0);
            selected_bank <= ba;
            if mode_reg(9) = '1' then 
               wr_burst <= "000000001";
            else
               case mode_reg(2 downto 0) is
                  when "000" => wr_burst <= "000000001";
                  when "001" => wr_burst <= "000000011";
                  when "010" => wr_burst <= "000001111";
                  when "011" => wr_burst <= "011111111";
                  when "111" => wr_burst <= "111111111";  -- full page
                  when others =>
               end case;
            end if;
         elsif command = lmr_c then
            mode_reg <= addr;
         elsif command = act_c then
            -- Open a row in a bank
            active_row(to_integer(unsigned(ba)))    <= addr(2 downto 0);
            is_row_active(to_integer(unsigned(ba))) <= '1';
         elsif command = pre_c then
            -- Close off the row
            active_row(to_integer(unsigned(ba)))    <= (others => 'X');
            is_row_active(to_integer(unsigned(ba))) <= '0';
         elsif command = RD_c then
            wr_burst      <= (others => '0');
            column        <= addr(8 downto 0);
            selected_bank <= ba;
            -- This sets the bust length
            case mode_reg(2 downto 0) is
               when "000" => rd_burst <= "000000001" & rd_burst(1);
               when "001" => rd_burst <= "000000011" & rd_burst(1);
               when "010" => rd_burst <= "000001111" & rd_burst(1);
               when "011" => rd_burst <= "011111111" & rd_burst(1);
               when "111" => rd_burst <= "111111111" & rd_burst(1);  -- full page
               when others =>
                  -- full page not implemnted
            end case;
         end if;         

         -- This is the logic that implements the CAS delay. Here is enough for CAS=2
         if mode_reg(6 downto 4) = "010" then
            data_delay1 <= memory(to_integer(unsigned(addr_index)));
         elsif mode_reg(6 downto 4) = "011" then
            data_delay1 <=  data_delay2;
            data_delay2 <= memory(to_integer(unsigned(addr_index)));         
         else
            data_delay1 <=  data_delay2;
            data_delay2 <=  data_delay3;
            data_delay3 <= memory(to_integer(unsigned(addr_index)));
         end if;

         -- Output masks lag a cycle 
         dqm_sr  <= dqm & dqm_sr(3 downto 2);
         wr_mask <= not dqm;

      end if;
   end process;
      
data2_process : process(clk)
   begin
      if rising_edge(clk) then
         if rd_burst(0) = '1' and dqm_sr(0) = '0' then
            dq( 7 downto 0) <= data_delay1(7 downto 0) after 4 ns;
         else
            dq( 7 downto 0) <= "ZZZZZZZZ" after 4.0 ns;
         end if;

         if rd_burst(0) = '1' and dqm_sr(1) = '0' then
            dq(15 downto 8) <= data_delay1(15 downto 8) after 4.0 ns;
            -- Move onto the next address in the active row
         else
            dq(15 downto 8) <= "ZZZZZZZZ" after 4.0 ns;
         end if;
      elsif falling_edge(clk) then
         dq <= (others => 'Z') after 4.5 ns;
      end if;
   end process;

end Behavioral;