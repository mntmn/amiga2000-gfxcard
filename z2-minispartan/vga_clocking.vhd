----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
-- 
-- Description: Generate clocking for sending TMDS data use the OSERDES2
-- 
-- WHEN SENDING SOMETHING OTHER THAN 5 BITS AT a timeCHANGE 'DIVIDE' 
--
-- REMEMBER TO CHECK CLKIN_PERIOD ON PLL_BASE
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity vga_clocking is
    Port ( clk50           : in  STD_LOGIC;
           pixel_clock     : out STD_LOGIC);
end vga_clocking;

architecture Behavioral of vga_clocking is
   signal clock_x1             : std_logic;
   signal clock_x1_unbuffered  : std_logic;
   signal clk_feedback         : std_logic;
   signal clk50_buffered       : std_logic;
   signal pll_locked           : std_logic;
begin
   pixel_clock     <= clock_x1;
   
   -- Multiply clk50m by 15, then divide by 10 for the 75 MHz pixel clock
   -- Because the all come from the same PLL the will all be in phase 
   PLL_BASE_inst : PLL_BASE
   generic map (
      CLKFBOUT_MULT => 15,                  
      CLKOUT0_DIVIDE => 10,       CLKOUT0_PHASE => 0.0,  -- Output pixel clock, 1.5x original frequency
      CLK_FEEDBACK => "CLKFBOUT",                        -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      CLKIN_PERIOD => 20.0,                              -- IMPORTANT! 20.00 => 50MHz
      DIVCLK_DIVIDE => 1                                 -- Division value for all output clocks (1-52)
   )
      port map (
      CLKFBOUT => clk_feedback, 
      CLKOUT0  => clock_x1_unbuffered,
      CLKOUT1  => open,
      CLKOUT2  => open,
      CLKOUT3  => open,
      CLKOUT4  => open,
      CLKOUT5  => open,
      LOCKED   => pll_locked,      
      CLKFBIN  => clk_feedback,    
      CLKIN    => clk50_buffered, 
      RST      => '0'              -- 1-bit input: Reset input
   );

BUFG_clk    : BUFG port map ( I => clk50,                O => clk50_buffered);
BUFG_pclock : BUFG port map ( I => clock_x1_unbuffered,  O => clock_x1);

end Behavioral;