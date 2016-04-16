----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description: Memory tester - write then read back the first 16 words.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memory_tester is
    Generic (address_width : natural := 23);
    Port ( clk           : in  STD_LOGIC;

           cmd_enable      : out std_logic;
           cmd_wr          : out std_logic;
           cmd_address     : out std_logic_vector(address_width-1 downto 0);
           cmd_byte_enable : out std_logic_vector(3 downto 0);
           cmd_data_in     : out std_logic_vector(31 downto 0);    
           cmd_ready       : in std_logic;

           data_out        : in std_logic_vector(31 downto 0);
           data_out_ready  : in std_logic;

           debug           : out std_logic_vector(15 downto 0);    

           error_testing : out STD_LOGIC;
           blink         : out STD_LOGIC);
end Memory_tester;

architecture Behavioral of Memory_tester is
   constant terminal_count   : unsigned(address_width+5 downto 0) := (others => '1'); 
   signal has_errored        : STD_LOGIC := '0';
   signal b                  : STD_LOGIC := '0';
   signal e                  : STD_LOGIC := '1';

   -- for the read/write commands
   signal test_counter         : unsigned(address_width+5 downto 0) := (others => '0');
   signal test_pattern_index   : unsigned(3 downto 0);
   signal test_addr            : STD_LOGIC_VECTOR (address_width-1 downto 0);
   signal test_pattern         : STD_LOGIC_VECTOR (31 downto 0);
   signal test_wr              : STD_LOGIC := '1';
   signal test_write_all_first : STD_LOGIC;

   -- for the checking of read data
   signal read_counter       : unsigned(address_width+3 downto 0) := (others => '0');
   signal read_pattern_index : unsigned(3 downto 0);
   signal read_pattern       : STD_LOGIC_VECTOR (31 downto 0);
   signal wanted             : STD_LOGIC_VECTOR (31 downto 0);
   signal received           : STD_LOGIC_VECTOR (31 downto 0);
   signal read_write_order   : STD_LOGIC;
   signal read_addr          : STD_LOGIC_VECTOR (address_width-1 downto 0);
   signal debug_dump         : STD_LOGIC_VECTOR (7 downto 0) := (others => '1');
begin
   -------------------------------------
   -- split out the parts of the counter
   -------------------------------------
   
   -- Which test pattern are we running?
   test_write_all_first <= test_counter(address_width+5);
   test_pattern_index   <= test_counter(address_width+4 downto address_width+1);
   
   -- which order? write all then read_all (0) or write_one then read_one (1)
   with test_write_all_first select test_addr <= std_logic_vector(test_counter(address_width-1 downto 0)) when '1', 
                                                 std_logic_vector(test_counter(address_width   downto 1)) when others;
   with test_write_all_first select test_wr   <= not std_logic(test_counter(address_width)) when '1',
                                                 not std_logic(test_counter(0)) when others;
 
   -- What data are we expecting to come back from RAM
   read_pattern_index <= read_counter(address_width+3 downto address_width);
   read_addr          <= std_logic_vector(read_counter(address_width-1 downto 0));
                                           
   cmd_wr          <= test_wr;
   error_testing   <= has_errored;
   blink           <= b;
   cmd_enable      <= '1';
   cmd_data_in     <= test_pattern;
   cmd_address     <= test_addr;
   cmd_byte_enable <= (others =>'1');
   
   
   
tp: process(test_pattern_index, test_addr)
  begin
    case test_pattern_index is
      when "0000" => test_pattern <= x"00000000"; -- all zeros
      when "0001" => test_pattern <= x"FFFFFFFF"; -- all ones
      when "0010" => if test_addr(0) = '0' then -- even checkerboard (32 bit data bus)
                        test_pattern <= x"AAAAAAAA"; 
                     else 
                        test_pattern <= x"55555555";
                     end if;
      when "0011" => if test_addr(0) = '0' then -- odd checkerboard (32 bit data bus)
                        test_pattern <= x"55555555";
                     else 
                        test_pattern <= x"AAAAAAAA"; 
                     end if;
      when "1111" => test_pattern <= x"AAAA5555"; -- odd checkerboard (16 bit data bus)
      when "0101" => test_pattern <= x"5555AAAA"; -- even checkerboard (16 bit data bus)
      when "0110" => test_pattern <= x"AA55AA55"; -- odd checkerboard (8 bit data bus)
      when "0111" => test_pattern <= x"55AA55AA"; -- even checkerboard (8 bit data bus)
      when "1000" => test_pattern <= x"11111111"; 
      when "1001" => test_pattern <= x"22222222";
      when "1010" => test_pattern <= x"44444444";
      when "1011" => test_pattern <= x"88888888";
      when "1100" => test_pattern <= x"EEEEEEEE";
      when "1101" => test_pattern <= x"DDDDDDDD";
      when "1110" => test_pattern <= x"BBBBBBBB";
      when others => test_pattern <= (others =>'0');
                     test_pattern(test_addr'high downto 0) <= test_addr;
    end case;
  end process;

rtp: process(read_pattern_index, read_addr)
  begin
    case read_pattern_index is
      when "0000" => read_pattern <= x"00000000"; -- all zeros
      when "0001" => read_pattern <= x"FFFFFFFF"; -- all ones
      when "0010" => if read_addr(0) = '0' then -- even checkerboard (32 bit data bus)
                        read_pattern  <= x"AAAAAAAA"; 
                     else 
                        read_pattern  <= x"55555555";
                     end if;
      when "0011" => if read_addr(0) = '0' then -- odd checkerboard (32 bit data bus)
                        read_pattern <= x"55555555";
                     else 
                        read_pattern <= x"AAAAAAAA"; 
                     end if;
      when "1111" => read_pattern <= x"AAAA5555"; -- odd checkerboard (16 bit data bus)
      when "0101" => read_pattern <= x"5555AAAA"; -- even checkerboard (16 bit data bus)
      when "0110" => read_pattern <= x"AA55AA55"; -- odd checkerboard (8 bit data bus)
      when "0111" => read_pattern <= x"55AA55AA"; -- even checkerboard (8 bit data bus)
      when "1000" => read_pattern <= x"11111111"; 
      when "1001" => read_pattern <= x"22222222";
      when "1010" => read_pattern <= x"44444444";
      when "1011" => read_pattern <= x"88888888";
      when "1100" => read_pattern <= x"EEEEEEEE";
      when "1101" => read_pattern <= x"DDDDDDDD";
      when "1110" => read_pattern <= x"BBBBBBBB";
      when others => read_pattern <= (others =>'0');
                     read_pattern(read_addr'high downto 0) <= read_addr;
    end case;
  end process;
  
process(clk)
   begin
      if rising_edge(clk) then         
         -------------------------------------------------------
         -- If a test failure is observed, the module will dump 
         -- out 8 words of status on the "debug" line. 
         -------------------------------------------------------
         if has_errored = '1' then
            case debug_dump is
               when "11111111" => debug <= has_errored & std_logic_vector(read_counter(14 downto 0));
               when "01111111" => debug <= (others => '0');
                               debug(read_counter'high-15 downto 0) <= std_logic_vector(read_counter(read_counter'high downto 15));
               when "00111111" => debug <= (others => '0');
               when "00011111" => debug <= received(15 downto 0); -- use received as data_out might have changed by now!
               when "00001111" => debug <= received(31 downto 16);
               when "00000111" => debug <= (others => '0');
               when "00000011" => debug <= wanted(15 downto 0); 
               when "00000001" => debug <= wanted(31 downto 16);
               when others     => debug <= (others => '0');
            end case;

            debug_dump <= '0' & debug_dump(debug_dump'high downto 1);
         else
            debug_dump <= (others => '1');
            debug <= "0" & test_pattern(14 downto 0);
         end if;

         if e = '1' then
            if cmd_ready = '1' then  -- the transaction will be accepted this cycle
                -- Blink the LED every time the counter roles over (for later use)
               if test_counter = terminal_count then
                  b <= not b;
               end if;          
               -- Move on to the next transaction
               test_counter <= test_counter+1;                  
            end if;

            if data_out_ready = '1' then
               received <= data_out;
               wanted   <= read_pattern;
               if data_out /= read_pattern then
                  has_errored <= '1';
                  e <= '0';
               else
                  read_counter <= read_counter+1;                  
               end if;
            end if;
         end if;
      end if;
   end process;
end Behavioral;