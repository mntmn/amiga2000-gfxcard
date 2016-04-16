----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description: Top level module for the LogiPi SDRAM controller project 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity top_level is
    Port ( clk_32      : in  STD_LOGIC;
           led1        : out  STD_LOGIC;
           SDRAM_CLK   : out  STD_LOGIC;
           SDRAM_CKE   : out  STD_LOGIC;
           SDRAM_CS    : out  STD_LOGIC;
           SDRAM_nRAS  : out  STD_LOGIC;
           SDRAM_nCAS  : out  STD_LOGIC;
           SDRAM_nWE   : out  STD_LOGIC;
           SDRAM_DQM   : out  STD_LOGIC_VECTOR( 1 downto 0);
           SDRAM_ADDR  : out  STD_LOGIC_VECTOR (12 downto 0);
           SDRAM_BA    : out   STD_LOGIC_VECTOR( 1 downto 0);
           SDRAM_DQ    : inout  STD_LOGIC_VECTOR (15 downto 0);
           
           tx       : out std_logic);
end top_level;

architecture Behavioral of top_level is
   constant sdram_address_width : natural := 22;
   constant sdram_column_bits   : natural := 8;
   constant sdram_startup_cycles: natural := 10100; -- 100us, plus a little more
   constant cycles_per_refresh  : natural := (64000*100)/4196-1;
   
   constant test_width          : natural := sdram_address_width-1; -- each 32-bit word is two 16-bit SDRAM addresses 

	COMPONENT SDRAM_Controller
    generic (
      sdram_address_width : natural;
      sdram_column_bits   : natural;
      sdram_startup_cycles: natural;
      cycles_per_refresh  : natural
    );
    PORT(
		clk             : IN std_logic;
		reset           : IN std_logic;
      
      -- Interface to issue commands
		cmd_ready       : OUT std_logic;
		cmd_enable      : IN  std_logic;
		cmd_wr          : IN  std_logic;
      cmd_address     : in  STD_LOGIC_VECTOR(sdram_address_width-2 downto 0); -- address to read/write
		cmd_byte_enable : IN  std_logic_vector(3 downto 0);
		cmd_data_in     : IN  std_logic_vector(31 downto 0);    
      
      -- Data being read back from SDRAM
		data_out        : OUT std_logic_vector(31 downto 0);
		data_out_ready  : OUT std_logic;

      -- SDRAM signals
		SDRAM_CLK       : OUT   std_logic;
		SDRAM_CKE       : OUT   std_logic;
		SDRAM_CS        : OUT   std_logic;
		SDRAM_RAS       : OUT   std_logic;
		SDRAM_CAS       : OUT   std_logic;
		SDRAM_WE        : OUT   std_logic;
		SDRAM_DQM       : OUT   std_logic_vector(1 downto 0);
		SDRAM_ADDR      : OUT   std_logic_vector(12 downto 0);
		SDRAM_BA        : OUT   std_logic_vector(1 downto 0);
		SDRAM_DATA      : INOUT std_logic_vector(15 downto 0)     
		);
	END COMPONENT;

	COMPONENT SDRAM_Controller_v
	PORT(
		clk             : IN std_logic;
		reset           : IN std_logic;
      --
		cmd_enable      : IN std_logic;
		cmd_wr          : IN std_logic;
		cmd_byte_enable : IN std_logic_vector(3 downto 0);
		cmd_address     : IN std_logic_vector(20 downto 0);
		cmd_data_in     : IN std_logic_vector(31 downto 0);    
		cmd_ready       : OUT std_logic;
      --
		data_out        : OUT std_logic_vector(31 downto 0);
		data_out_ready  : OUT std_logic;
      --
		SDRAM_CLK  : OUT std_logic;
		SDRAM_CKE  : OUT std_logic;
		SDRAM_CS   : OUT std_logic;
		SDRAM_RAS  : OUT std_logic;
		SDRAM_CAS  : OUT std_logic;
		SDRAM_WE   : OUT std_logic;
		SDRAM_DQM  : OUT std_logic_vector(1 downto 0);
		SDRAM_ADDR : OUT std_logic_vector(12 downto 0);
		SDRAM_DATA : INOUT std_logic_vector(15 downto 0);      
		SDRAM_BA   : OUT std_logic_vector(1 downto 0)
		);
	END COMPONENT;

	COMPONENT blinker
	PORT(
		clk : IN std_logic;
		i : IN std_logic;          
		o : OUT std_logic
		);
	END COMPONENT;

   COMPONENT cheapscope
      GENERIC( tx_freq :natural);
      PORT(  capture_clk : IN  std_logic;
             tx_clk      : IN  std_logic;
             probes      : IN  std_logic_vector(15 downto 0);          
             serial_tx   : OUT std_logic);
   END COMPONENT;
   
   COMPONENT Memory_tester
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

           error_testing   : out STD_LOGIC;
           blink           : out STD_LOGIC);
   END COMPONENT;

   -- signals for clocking
   signal clk, clku, clk_mem, clk_memu, clkfb, clkb   : std_logic;
   
   -- signals to interface with the memory controller
   signal cmd_address     : std_logic_vector(test_width-1 downto 0) := (others => '0');
   signal cmd_wr          : std_logic := '1';
   signal cmd_enable      : std_logic;
   signal cmd_byte_enable : std_logic_vector(3 downto 0);
   signal cmd_data_in     : std_logic_vector(31 downto 0);
   signal cmd_ready       : std_logic;
   signal data_out        : std_logic_vector(31 downto 0);
   signal data_out_ready  : std_logic;
   
   -- misc signals
   signal error_refresh   : std_logic;
   signal error_testing   : std_logic;
   signal blink           : std_logic;
   signal debug           : std_logic_vector(15 downto 0);
   signal tester_debug    : std_logic_vector(15 downto 0);
   signal is_idle         : std_logic;
   signal iob_data        : std_logic_vector(15 downto 0);      
   signal error_blink     : std_logic;
 
   begin
i_error_blink : blinker PORT MAP(
   clk => clk,
   i => error_testing,
   o => error_blink
   );
   
      led1 <= blink xor error_blink;

Inst_Memory_tester: Memory_tester GENERIC MAP(address_width => test_width) PORT MAP(
      clk             => clk,
      
      cmd_address     => cmd_address(test_width-1 downto 0),
      cmd_wr          => cmd_wr,
      cmd_enable      => cmd_enable,
      cmd_ready       => cmd_ready,
      cmd_byte_enable => cmd_byte_enable,
      cmd_data_in     => cmd_data_in,
      
      data_out        => data_out,
      data_out_ready  => data_out_ready,
      
      debug           => tester_debug,
      
      error_testing   => error_testing,
      blink           => blink
   );
   
   debug <= tester_debug;

Inst_SDRAM_Controller_v: SDRAM_Controller_v PORT MAP( 
      clk             => clk,
      reset           => '0',

      cmd_address     => cmd_address,
      cmd_wr          => cmd_wr,
      cmd_enable      => cmd_enable,
      cmd_ready       => cmd_ready,
      cmd_byte_enable => cmd_byte_enable,
      cmd_data_in     => cmd_data_in,
      
      data_out        => data_out,
      data_out_ready  => data_out_ready,
   
      SDRAM_CLK       => SDRAM_CLK,
      SDRAM_CKE       => SDRAM_CKE,
      SDRAM_CS        => SDRAM_CS,
      SDRAM_RAS       => SDRAM_nRAS,
      SDRAM_CAS       => SDRAM_nCAS,
      SDRAM_WE        => SDRAM_nWE,
      SDRAM_DQM       => SDRAM_DQM,
      SDRAM_BA        => SDRAM_BA,
      SDRAM_ADDR      => SDRAM_ADDR,
      SDRAM_DATA      => SDRAM_DQ
   );

--Inst_SDRAM_Controller: SDRAM_Controller GENERIC MAP (
--      sdram_address_width => sdram_address_width,
--      sdram_column_bits   => sdram_column_bits,
--      sdram_startup_cycles=> sdram_startup_cycles,
--      cycles_per_refresh  => cycles_per_refresh
--   ) PORT MAP(
--      clk             => clk,
--      reset           => '0',
--
--      cmd_address     => cmd_address,
--      cmd_wr          => cmd_wr,
--      cmd_enable      => cmd_enable,
--      cmd_ready       => cmd_ready,
--      cmd_byte_enable => cmd_byte_enable,
--      cmd_data_in     => cmd_data_in,
--     
--      data_out        => data_out,
--      data_out_ready  => data_out_ready,
--   
--      SDRAM_CLK       => SDRAM_CLK,
--      SDRAM_CKE       => SDRAM_CKE,
--      SDRAM_CS        => SDRAM_CS,
--      SDRAM_RAS       => SDRAM_nRAS,
--      SDRAM_CAS       => SDRAM_nCAS,
--      SDRAM_WE        => SDRAM_nWE,
--      SDRAM_DQM       => SDRAM_DQM,
--      SDRAM_BA        => SDRAM_BA,
--      SDRAM_ADDR      => SDRAM_ADDR,
--      SDRAM_DATA      => SDRAM_DQ
--   );
   -------------------------------------
Inst_cheapscope: cheapscope GENERIC MAP (
      tx_freq => 32000000*3
   ) PORT MAP(
      capture_clk => clk,
      probes      => debug,
      tx_clk      => clk,
      serial_tx   => tx
   );

   
PLL_BASE_inst : PLL_BASE generic map (
      BANDWIDTH => "OPTIMIZED",             -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT => 24,                  -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output (0.0-360.0).
      CLKIN_PERIOD => 31.25,               -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 8,      CLKOUT1_DIVIDE =>  8,
      CLKOUT2_DIVIDE => 1,       CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,       CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5, CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5, CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5, CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE => 0.0,      CLKOUT1_PHASE => 0.0, -- Capture clock
      CLKOUT2_PHASE => 0.0,      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,      CLKOUT5_PHASE => 0.0,
      
      CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
      REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
   ) port map (
      CLKFBOUT => CLKFB, -- 1-bit output: PLL_BASE feedback output
      -- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      CLKOUT0 => CLKu,      CLKOUT1 => CLK_MEMu,
      CLKOUT2 => open,      CLKOUT3 => open,
      CLKOUT4 => open,      CLKOUT5 => open,
      LOCKED  => open,  -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => CLKFB, -- 1-bit input: Feedback clock input
      CLKIN   => clkb,  -- 1-bit input: Clock input
      RST     => '0'    -- 1-bit input: Reset input
   );

   -- Buffering of clocks
BUFG_1 : BUFG port map (O => clkb,    I => clk_32);
BUFG_3 : BUFG port map (O => clk,     I => clku);

end Behavioral;