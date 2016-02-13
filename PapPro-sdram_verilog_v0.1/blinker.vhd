----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:38:09 10/11/2013 
-- Design Name: 
-- Module Name:    blinker - Behavioral 
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

entity blinker is
    Port ( clk : in  STD_LOGIC;
           i : in  STD_LOGIC;
           o : out  STD_LOGIC);
end blinker;

architecture Behavioral of blinker is
   signal counter : unsigned( 23 downto 0) := (others => '0');
begin

process(clk)
  begin
     if rising_edge(clk) then
        counter <= counter+1;
        o <= i and std_logic(counter(counter'high));
     end if;
  end process;
end Behavioral;

