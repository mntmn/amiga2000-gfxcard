----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- I've put this together for my personal use. You are welcome to use it however
-- your like. Just because it fits my needs it may not fit yours, if so, bad luck.
--
-- Description: 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

entity Capture is
    Port ( clk             : in  STD_LOGIC;
           probes          : in  STD_LOGIC_VECTOR (15 downto 0);
           
           write_address   : out STD_LOGIC_VECTOR (9 downto 0);
           write_data      : out STD_LOGIC_VECTOR (15 downto 0);
           write_enable    : out STD_LOGIC;
           
           capture_done    : out STD_LOGIC;
           arm_again       : in  STD_LOGIC;
           trigger_address : out STD_LOGIC_VECTOR (9 downto 0)
         );
end Capture;

architecture Behavioral of Capture is
   constant STATE_ARMING    : std_logic_vector(1 downto 0) := "00"; 
   constant STATE_ARMED     : std_logic_vector(1 downto 0) := "01"; 
   constant STATE_TRIGGERED : std_logic_vector(1 downto 0) := "10"; 
   constant STATE_DONE      : std_logic_vector(1 downto 0) := "11"; 
   signal state      : std_logic_vector(1 downto 0) := STATE_ARMING;

   signal address  : std_logic_vector(9 downto 0) := (others => '0');
   signal captured : std_logic_vector(9 downto 0) := (others => '0');
   signal last     : std_logic_vector(15 downto 0)  := (others => '0');
begin
   process(clk)
   begin
      if rising_edge(clk) then
         write_data    <= probes;
         write_address <= address;
         address       <= address+1;
         case state is
            when STATE_ARMING    =>
               capture_done <= '0';
               write_enable  <= '1';
               if captured = "0111111111" then 
                  state <= STATE_ARMED;
               end if;
               captured      <= captured+1;
            when STATE_ARMED     =>
               write_enable    <= '1';
               trigger_address <= address;
--============================
-- Trigger gotes here
--============================            
               if probes(15) = '1' then
                  state           <= STATE_TRIGGERED;
               end if;
--============================
            when STATE_TRIGGERED =>
               write_enable  <= '1';
               if captured = "1111111111" then 
                  capture_done <= '1';
                  state <= STATE_DONE;
               end if;
               captured      <= captured+1;
            when STATE_DONE      =>
               write_enable <= '0';
               if arm_again = '1' then 
                  state <= STATE_ARMING;
               end if;
            when others  =>
         end case;
         last <= probes;
      end if;
   end process;
end Behavioral;