----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
-- 
-- Description: Generate clocking for sending TMDS data use the OSERDES2
-- 
-- REMEMBER TO CHECK CLKIN_PERIOD ON PLL_BASE
-- For pixel rates between 25Mhz and 50MHz use the following PLL settings:
--      CLKFBOUT_MULT => 20,                  
--      CLKOUT0_DIVIDE => 2,       CLKOUT0_PHASE => 0.0,   -- Output 10x original frequency
--      CLKOUT1_DIVIDE => 10,       CLKOUT1_PHASE => 0.0,   -- Output 2x original frequency
--      CLKOUT2_DIVIDE => 20,      CLKOUT2_PHASE => 0.0,   -- Output 1x original frequency
--      CLKIN_PERIOD   => 20.0,
--
-- For pixel rates between 40Mhz and 100MHz use the following PLL settings:
--      CLKFBOUT_MULT => 10,                  
--      CLKOUT0_DIVIDE => 1,       CLKOUT0_PHASE => 0.0,   -- Output 10x original frequency
--      CLKOUT1_DIVIDE => 5,       CLKOUT1_PHASE => 0.0,   -- Output 2x original frequency
--      CLKOUT2_DIVIDE => 10,      CLKOUT2_PHASE => 0.0,   -- Output 1x original frequency
--      CLKIN_PERIOD   => 10.0,
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity dvid_out_clocking is
  Port ( 
    clk_pixel     : in  STD_LOGIC;
    reset : in STD_LOGIC;
    clk_x1        : out STD_LOGIC;  
    clk_x2        : out STD_LOGIC;  
    clk_x10       : out STD_LOGIC;
    serdes_strobe : out STD_LOGIC
  );
end dvid_out_clocking;

architecture Behavioral of dvid_out_clocking is
  signal clock_local_x1       : std_logic;
  signal clock_local_x2       : std_logic;
  signal clock_local_x10      : std_logic;
  signal clock_x10_unbuffered : std_logic;
  signal clock_x2_unbuffered  : std_logic;
  signal clock_x1_unbuffered  : std_logic;
  signal clk_feedback         : std_logic;
  signal clk50_buffered       : std_logic;
  signal pll_locked           : std_logic;
begin
  clk_x1  <= clock_local_x1;
  clk_x2  <= clock_local_x2;
  clk_x10 <= clock_local_x10;

  -- Multiply clk50m by 10, then :
  -- * divide by 1 for the bit clock (pixel clock x10)
  -- * divide by 5 for the pixel clock x2 
  -- * divide by 10 for the pixel clock
  -- Because the all come from the same PLL the will all be in phase 
  PLL_BASE_inst : PLL_BASE
  generic map (
    CLKFBOUT_MULT => 10,                  
    CLKOUT0_DIVIDE => 1,       CLKOUT0_PHASE => 0.0,   -- Output 10x original frequency
    CLKOUT1_DIVIDE => 5,       CLKOUT1_PHASE => 0.0,   -- Output 2x original frequency
    CLKOUT2_DIVIDE => 10,      CLKOUT2_PHASE => 0.0,   -- Output 1x original frequency
    CLKIN_PERIOD => 10.0,

    --CLKFBOUT_MULT => 20,                  
    --CLKOUT0_DIVIDE => 2,       CLKOUT0_PHASE => 0.0,   -- Output 10x original frequency
    --CLKOUT1_DIVIDE => 10,       CLKOUT1_PHASE => 0.0,   -- Output 2x original frequency
    --CLKOUT2_DIVIDE => 20,      CLKOUT2_PHASE => 0.0,   -- Output 1x original frequency
    --CLKIN_PERIOD   => 20.0,

    CLK_FEEDBACK => "CLKFBOUT",
    DIVCLK_DIVIDE => 1
  )
  
  port map (
    CLKFBOUT => clk_feedback, 
    CLKOUT0  => clock_x10_unbuffered,
    CLKOUT1  => clock_x2_unbuffered,
    CLKOUT2  => clock_x1_unbuffered,
    CLKOUT3  => open,
    CLKOUT4  => open,
    CLKOUT5  => open,
    LOCKED   => pll_locked,      
    CLKFBIN  => clk_feedback,    
    CLKIN    => clk_pixel, 
    RST      => reset
  );

  BUFG_pclockx2  : BUFG port map ( I => clock_x2_unbuffered,  O => clock_local_x2);
  BUFG_pclock    : BUFG port map ( I => clock_x1_unbuffered,  O => clock_local_x1);

  BUFPLL_inst : BUFPLL
  generic map (
    DIVIDE => 5,         -- DIVCLK divider (1-8) !!!! IMPORTANT TO CHANGE THIS AS NEEDED !!!!
    ENABLE_SYNC => TRUE  -- Enable synchrnonization between PLL and GCLK (TRUE/FALSE) -- should be true
  )
  port map (
    IOCLK        => clock_local_x10,       -- Clock used to send bits
    LOCK         => open,                 
    SERDESSTROBE => serdes_strobe,         -- Clock use to load data into SERDES 
    GCLK         => clock_local_x2,        -- Global clock use as a reference for serdes_strobe
    LOCKED       => pll_locked,            -- When the upstream PLL is locked 
    PLLIN        => clock_x10_unbuffered   -- What clock to use - this must be unbuffered
  );
end Behavioral;