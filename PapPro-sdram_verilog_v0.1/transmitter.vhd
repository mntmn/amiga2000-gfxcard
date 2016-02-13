----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description:  Transmitter - the RS232 TX component for cheapscope
--
-- I've put this together for my personal use. You are welcome to use it however
-- your like. Just because it fits my needs it may not fit yours, if so, bad luck.
--
-- v2.0 Changed BRAM to 4bit/16bit to reduce logic
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Transmitter is
    generic (FREQUENCY : natural );
    Port ( clk             : in  STD_LOGIC;
           serial_tx       : out STD_LOGIC;
           ram_data        : in  STD_LOGIC_VECTOR(3 downto 0);
           ram_address     : out STD_LOGIC_VECTOR(11 downto 0);
           capture_done    : in  STD_LOGIC;
           trigger_address : in  STD_LOGIC_VECTOR(9 downto 0);
           arm_again       : out STD_LOGIC);
end Transmitter;

architecture Behavioral of Transmitter is

   COMPONENT bin2ascii
   PORT(
      value : IN std_logic_vector(3 downto 0);          
      char : OUT std_logic_vector(7 downto 0)
      );
   END COMPONENT;

   -- For the binary to ASCII Hex conversion
   signal ascii_data : std_logic_vector(9 downto 0);
   
   -- Where we are in RAM readback 
   signal xmit_address : std_logic_vector(11 downto 0) := (others => '0');

   -- The FSM to control sending data 
   constant STATE_WAITING : std_logic_vector(2 downto 0) := "000"; 
   constant STATE_XMIT    : std_logic_vector(2 downto 0) := "001"; 
   constant STATE_NL      : std_logic_vector(2 downto 0) := "010"; 
   constant STATE_CR      : std_logic_vector(2 downto 0) := "011"; 
   constant STATE_REARM   : std_logic_vector(2 downto 0) := "100"; 
   signal state           : std_logic_vector(2 downto 0) := STATE_WAITING;
   
   -- The RS232 interface
   constant TERMINAL_COUNT : std_logic_vector(15 downto 0) := x"0000"+FREQUENCY/19200;
   signal   xmit_cnt       : std_logic_vector(15 downto 0) := (others => '1');
   signal   shift_reg      : std_logic_vector( 9 downto 0) := (others => '1');
   signal   shift_busy     : std_logic_vector(10 downto 0) := (others => '0');
begin
   -- Assign the outgoing RS232 signal
   serial_tx <= shift_reg(0);
   
   -- the '11' on the end of the xor reverses the order of the nibbles being sent up the line.
   ram_address <= (trigger_address & "00") + (xmit_address XOR "100000000011");   
process(ram_data)
   begin
      case ram_data is 
         when x"0"   => ascii_data <= "1" & x"30" & "0";
         when x"1"   => ascii_data <= "1" & x"31" & "0";
         when x"2"   => ascii_data <= "1" & x"32" & "0";
         when x"3"   => ascii_data <= "1" & x"33" & "0";
         when x"4"   => ascii_data <= "1" & x"34" & "0";
         when x"5"   => ascii_data <= "1" & x"35" & "0";
         when x"6"   => ascii_data <= "1" & x"36" & "0";
         when x"7"   => ascii_data <= "1" & x"37" & "0";
         when x"8"   => ascii_data <= "1" & x"38" & "0";
         when x"9"   => ascii_data <= "1" & x"39" & "0";
         when x"A"   => ascii_data <= "1" & x"41" & "0";
         when x"B"   => ascii_data <= "1" & x"42" & "0";
         when x"C"   => ascii_data <= "1" & x"43" & "0";
         when x"D"   => ascii_data <= "1" & x"44" & "0";
         when x"E"   => ascii_data <= "1" & x"45" & "0";
         when others => ascii_data <= "1" & x"46" & "0";
      end case;
   end process;

   process (clk)
   begin
      if rising_edge(clk) then
         case state is
            when STATE_WAITING =>
               -- do nothing while we wait for the capture to finish
               arm_again <= '0';
               if capture_done = '1' and xmit_cnt = 0 then
                  xmit_cnt        <= (others => '0');
                  shift_reg       <= ascii_data; 
                  shift_busy      <= (others => '1');
                  xmit_address    <= (others => '0');
                  xmit_address(0) <= '1';
                  state           <= STATE_XMIT;   
               else
                  state <= STATE_WAITING;   
               end if;
            when STATE_XMIT =>
               if shift_busy(0) = '0' then
                  if xmit_address = 0 then
                     state <= STATE_NL;
                     shift_reg  <= "1000010100";  -- NL.
                     shift_busy   <= (others => '1');
                  else
                     xmit_address <= xmit_address+1;
                     shift_reg    <= ascii_data;
                     shift_busy   <= (others => '1');
                  end if;
               end if;
            when STATE_NL =>
               state <= STATE_NL;
               if shift_busy(0) = '0' then
                   shift_reg   <= "1000011010";  -- CR.
                   shift_busy  <= (others => '1');
                  state <= STATE_CR;
               end if;
            when STATE_CR =>
               state <= STATE_CR;
               if shift_busy(0) = '0' then
                  state <= STATE_REARM;
               end if;
            when STATE_REARM =>
               if capture_done = '1' then
                  arm_again <= '1';
                  state <= STATE_REARM;
               else
                  state <= STATE_WAITING;
               end if;
            when others =>
               state <= STATE_WAITING;
         end case;
         
         -- Sending out the RS232 bits
         if xmit_cnt = TERMINAL_COUNT then
            shift_reg    <= '1' & shift_reg(9 downto 1); 
            shift_busy   <= '0' & shift_busy(10 downto 1);
            xmit_cnt     <= (others => '0');
         else
            xmit_cnt <= xmit_cnt+1;
         end if;
      end if;
   end process;
end Behavioral;