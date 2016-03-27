----------------------------------------------------------------------------------
-- Engineer:   Mike Field <hamster@snap.net.nz>
-- 
-- Module Name: output_serialiser - Behavioral 
-- Description: A 5-bit SDR output serialiser
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity output_serialiser is
    Port ( clk_load   : in  STD_LOGIC;
           clk_output : in  STD_LOGIC;
           strobe     : in  STD_LOGIC;
           ser_data   : in  STD_LOGIC_VECTOR (4 downto 0);
           ser_output : out STD_LOGIC);
end output_serialiser;

architecture Behavioral of output_serialiser is
   signal clk0,     clk1,     clkdiv : std_logic;
   signal cascade1, cascade2, cascade3, cascade4 : std_logic;
begin
   clkdiv <= clk_load;
   clk0   <= clk_output;
   clk1   <= '0';
   
OSERDES2_master : OSERDES2
   generic map (
      BYPASS_GCLK_FF => FALSE,       -- Bypass CLKDIV syncronization registers (TRUE/FALSE)
      DATA_RATE_OQ => "SDR",         -- Output Data Rate ("SDR" or "DDR")
      DATA_RATE_OT => "SDR",         -- 3-state Data Rate ("SDR" or "DDR")
      DATA_WIDTH => 5,               -- Parallel data width (2-8)
      OUTPUT_MODE => "SINGLE_ENDED", -- "SINGLE_ENDED" or "DIFFERENTIAL" 
      SERDES_MODE => "MASTER",       -- "NONE", "MASTER" or "SLAVE" 
      TRAIN_PATTERN => 0             -- Training Pattern (0-15)
   ) port map (
      OQ        => ser_output, -- 1-bit output: Data output to pad or IODELAY2
      SHIFTOUT1 => cascade1, -- 1-bit output: Cascade data output
      SHIFTOUT2 => cascade2, -- 1-bit output: Cascade 3-state output
      SHIFTOUT3 => open,     -- 1-bit output: Cascade differential data output
      SHIFTOUT4 => open,     -- 1-bit output: Cascade differential 3-state output
      SHIFTIN1  => '1',      -- 1-bit input: Cascade data input
      SHIFTIN2  => '1',      -- 1-bit input: Cascade 3-state input
      SHIFTIN3  => cascade3, -- 1-bit input: Cascade differential data input
      SHIFTIN4  => cascade4, -- 1-bit input: Cascade differential 3-state input
      TQ        => open,     -- 1-bit output: 3-state output to pad or IODELAY2
      CLK0      => CLK0,     -- 1-bit input: I/O clock input
      CLK1      => CLK1,     -- 1-bit input: Secondary I/O clock input
      CLKDIV    => CLKDIV,   -- 1-bit input: Logic domain clock input
      -- D1 - D4: 1-bit (each) input: Parallel data inputs
      D1        => ser_data(4),
      D2        => '0',
      D3        => '0',
      D4        => '0',
      IOCE      => strobe,   -- 1-bit input: Data strobe input
      OCE       => '1',      -- 1-bit input: Clock enable input
      RST       => '0',      -- 1-bit input: Asynchrnous reset input
      -- T1 - T4: 1-bit (each) input: 3-state control inputs
      T1       => '0',
      T2       => '0',
      T3       => '0',
      T4       => '0',
      TCE      => '1',       -- 1-bit input: 3-state clock enable input
      TRAIN    => '0'        -- 1-bit input: Training pattern enable input
   );

OSERDES2_slave : OSERDES2
   generic map (
      BYPASS_GCLK_FF => FALSE,       -- Bypass CLKDIV syncronization registers (TRUE/FALSE)
      DATA_RATE_OQ => "SDR",         -- Output Data Rate ("SDR" or "DDR")
      DATA_RATE_OT => "SDR",         -- 3-state Data Rate ("SDR" or "DDR")
      DATA_WIDTH => 5,               -- Parallel data width (2-8)
      OUTPUT_MODE => "SINGLE_ENDED", -- "SINGLE_ENDED" or "DIFFERENTIAL" 
      SERDES_MODE => "SLAVE",       -- "NONE", "MASTER" or "SLAVE" 
      TRAIN_PATTERN => 0             -- Training Pattern (0-15)
   ) port map (
      OQ        => open,            -- 1-bit output: Data output to pad or IODELAY2
      SHIFTOUT1 => open,     -- 1-bit output: Cascade data output
      SHIFTOUT2 => open,     -- 1-bit output: Cascade 3-state output
      SHIFTOUT3 => cascade3, -- 1-bit output: Cascade differential data output
      SHIFTOUT4 => cascade4, -- 1-bit output: Cascade differential 3-state output
      SHIFTIN1  => cascade1, -- 1-bit input: Cascade data input
      SHIFTIN2  => cascade2, -- 1-bit input: Cascade 3-state input
      SHIFTIN3  => '1',      -- 1-bit input: Cascade differential data input
      SHIFTIN4  => '1',      -- 1-bit input: Cascade differential 3-state input
      TQ        => open,      -- 1-bit output: 3-state output to pad or IODELAY2
      CLK0      => CLK0,      -- 1-bit input: I/O clock input
      CLK1      => CLK1,      -- 1-bit input: Secondary I/O clock input
      CLKDIV    => CLKDIV,    -- 1-bit input: Logic domain clock input
      -- D1 - D4: 1-bit (each) input: Parallel data inputs
      D1        => ser_data(0),
      D2        => ser_data(1),
      D3        => ser_data(2),
      D4        => ser_data(3),
      IOCE      => strobe,     -- 1-bit input: Data strobe input
      OCE       => '1',        -- 1-bit input: Clock enable input
      RST       => '0',        -- 1-bit input: Asynchrnous reset input
      -- T1 - T4: 1-bit (each) input: 3-state control inputs
      T1        => '0',
      T2        => '0',
      T3        => '0',
      T4        => '0',
      TCE       => '1',             -- 1-bit input: 3-state clock enable input
      TRAIN     => '0'             -- 1-bit input: Training pattern enable input
   );

end Behavioral;

