----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description: Cheapscope - captures signals and then sends them as ASCII 
--                           to the serial port
--
-- I've put this together for my personal use. You are welcome to use it however
-- your like. Just because it fits my needs it may not fit yours, if so, bad luck.
--
-- v2.0 Changed BRAM to 4bit/16bit to reduce logic count
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity cheapscope is
   generic (tx_freq : natural);
    Port ( capture_clk : in  STD_LOGIC;
           tx_clk : in  STD_LOGIC;
           probes : in  STD_LOGIC_VECTOR (15 downto 0);
           serial_tx : out  STD_LOGIC);
end cheapscope;

architecture Behavioral of cheapscope is

   COMPONENT Transmitter
   generic (FREQUENCY : natural );
   PORT(
      clk             : IN  std_logic;
      ram_data        : IN  std_logic_vector(3 downto 0);
      capture_done    : IN  std_logic;
      trigger_address : IN  std_logic_vector(9 downto 0);          
      serial_tx       : OUT std_logic;
      ram_address     : OUT std_logic_vector(11 downto 0);
      arm_again       : OUT std_logic
      );
   END COMPONENT;

   COMPONENT Capture
   PORT(
      clk             : IN std_logic;
      probes          : IN  std_logic_vector(15 downto 0);
      write_address   : OUT std_logic_vector( 9 downto 0);
      write_data      : OUT std_logic_vector(15 downto 0);
      write_enable    : OUT std_logic;
      capture_done    : OUT std_logic;
      trigger_address : OUT std_logic_vector(9 downto 0);
      arm_again       : IN std_logic
      );
   END COMPONENT;

   signal write_address: STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
   signal read_address:  STD_LOGIC_VECTOR(11 downto 0) := (others => '0');

   signal write_data      : STD_LOGIC_VECTOR(15 downto 0);
   signal read_data       : STD_LOGIC_VECTOR(3 downto 0);
   signal capture_done    : STD_LOGIC;
   signal trigger_address : STD_LOGIC_VECTOR(9 downto 0);
   signal arm_again       : STD_LOGIC;
   
   signal write_enable    : STD_LOGIC;
   
begin

   RAMB16_S18_S18_inst : RAMB16_S4_S18
   generic map (
      INIT_A => X"000", --  Value of output RAM registers on Port A at startup
      INIT_B => X"000", --  Value of output RAM registers on Port B at startup
      SRVAL_A => X"000", --  Port A ouput value upon SSR assertion
      SRVAL_B => X"000", --  Port B ouput value upon SSR assertion
      WRITE_MODE_A => "WRITE_FIRST", --  WRITE_FIRST, READ_FIRST or NO_CHANGE
      WRITE_MODE_B => "WRITE_FIRST", --  WRITE_FIRST, READ_FIRST or NO_CHANGE
      SIM_COLLISION_CHECK => "ALL")  -- "NONE", "WARNING", "GENERATE_X_ONLY", "ALL" 
   port map (
      DOA    => read_data,    -- Port A 4-bit Data Output
      ADDRA => read_address,  -- Port A 11-bit Address Input
      CLKA  => tx_clk,        -- Port A Clock
      DIA   => (others=>'0'), -- Port A 4-bit Data Input
      ENA   => '1',           -- Port A RAM Enable Input
      SSRA  => '0',           -- Port A Synchronous Set/Reset Input
      WEA   => '0',           -- Port A Write Enable Input
      
      DOB    => open,         -- Port B 16-bit Data Output
      DOPB  => open,          -- Port B 2-bit Parity Output
      ADDRB => write_address, -- Port B 11-bit Address Input
      CLKB  => capture_clk,   -- Port B Clock
      DIB   => write_data,    -- Port B 16-bit Data Input
      DIPB  => "00",          -- Port B 2-bit parity Input
      ENB   => '1',           -- Port B RAM Enable Input
      SSRB  => '0',           -- Port B Synchronous Set/Reset Input
      WEB   => write_enable   -- Port B Write Enable Input
   );

   Inst_Transmitter: Transmitter GENERIC MAP (
      frequency => tx_freq
   ) PORT MAP(
      clk             => tx_clk,
      serial_tx       => serial_tx,
      ram_data        => read_data,
      ram_address     => read_address,
      capture_done    => capture_done,
      trigger_address => trigger_address,
      arm_again       => arm_again
   );

   Inst_Capture: Capture PORT MAP(
      clk             => capture_clk,
      probes          => probes,
      write_address   => write_address,
      write_data      => write_data,
      capture_done    => capture_done,
      arm_again       => arm_again,
      trigger_address => trigger_address,
      write_enable    => write_enable
   );
end Behavioral;
