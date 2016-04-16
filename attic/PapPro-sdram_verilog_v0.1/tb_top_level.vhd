--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:42:02 09/15/2013
-- Design Name:   
-- Module Name:   C:/Users/hamster/Projects/FPGA/LogiPi_SDRAM/tb_top_level.vhd
-- Project Name:  LogiPi_SDRAM
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: top_level
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY tb_top_level IS
END tb_top_level;
 
ARCHITECTURE behavior OF tb_top_level IS 
 
    COMPONENT top_level
    PORT(
         clk_32      : IN   std_logic;
         led1        : out  STD_LOGIC;
         SDRAM_CLK   : OUT  std_logic;
         SDRAM_CKE   : OUT  std_logic;
         SDRAM_CS    : OUT  std_logic;
         SDRAM_nRAS  : OUT  std_logic;
         SDRAM_nCAS  : OUT  std_logic;
         SDRAM_nWE   : OUT  std_logic;
         SDRAM_BA    : OUT  std_logic_vector(1 downto 0);
         SDRAM_DQM   : OUT  std_logic_vector(1 downto 0);
         SDRAM_ADDR  : OUT  std_logic_vector(12 downto 0);
         SDRAM_DQ    : INOUT  std_logic_vector(15 downto 0);
          
         tx       : out std_logic
        );
    END COMPONENT;
    

	COMPONENT sdram_model
	PORT(
		CLK : IN std_logic;
		CKE : IN std_logic;
		CS_N : IN std_logic;
		RAS_N : IN std_logic;
		CAS_N : IN std_logic;
		WE_N : IN std_logic;
		DQM : IN std_logic_vector(1 downto 0);
      BA      : in  STD_LOGIC_VECTOR (1 downto 0);
		ADDR : IN std_logic_vector(12 downto 0);       
		DQ : INOUT std_logic_vector(15 downto 0)
		);
	END COMPONENT;


   --Inputs
   signal clk_32 : std_logic := '0';

	--BiDirs
   signal SDRAM_DQ    : std_logic_vector(15 downto 0);

 	--Outputs
   signal led1        : std_logic;
   signal SDRAM_CLK   : std_logic;
   signal SDRAM_CKE   : std_logic;
   signal SDRAM_CS_N  : std_logic;
   signal SDRAM_RAS_N : std_logic;
   signal SDRAM_CAS_N : std_logic;
   signal SDRAM_WE_N  : std_logic;
   signal SDRAM_BA    : std_logic_vector( 1 downto 0);
   signal SDRAM_DQM   : std_logic_vector( 1 downto 0);
   signal SDRAM_ADDR  : std_logic_vector(12 downto 0);
   -- Clock period definitions
   constant clk_period : time := 31.24 ns;
   
   signal tx : std_logic;
   
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top_level PORT MAP (
          clk_32       => clk_32,
          led1         => led1,
          SDRAM_CLK    => SDRAM_CLK,
          SDRAM_CKE    => SDRAM_CKE,
          SDRAM_CS     => SDRAM_CS_N,
          SDRAM_nRAS   => SDRAM_RAS_N,
          SDRAM_nCAS   => SDRAM_CAS_N,
          SDRAM_nWE    => SDRAM_WE_N,
          SDRAM_DQM    => SDRAM_DQM,
          SDRAM_ADDR   => SDRAM_ADDR,
          SDRAM_BA     => SDRAM_BA,
          SDRAM_DQ     => SDRAM_DQ,
          tx => tx
        );

	Inst_sdram_model: sdram_model PORT MAP(
		CLK   => SDRAM_CLK,
		CKE   => SDRAM_CKE,
		CS_N  => SDRAM_CS_N,
		RAS_N => SDRAM_RAS_N,
		CAS_N => SDRAM_CAS_N,
		WE_N  => SDRAM_WE_N,
		DQM   => SDRAM_DQM,
		ADDR  => SDRAM_ADDR,
      BA    => SDRAM_BA,
		DQ    => SDRAM_DQ
	);

   -- Clock process definitions
clk_process :process
   begin
		clk_32 <= '0';
		wait for clk_period/2;
		clk_32 <= '1';
		wait for clk_period/2;
   end process;
 
   -- Stimulus process
stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;
END;
