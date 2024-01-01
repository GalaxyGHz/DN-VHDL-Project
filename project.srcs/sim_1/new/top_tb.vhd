----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/30/2023 10:11:50 AM
-- Design Name: 
-- Module Name: top_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_tb is
    --  Port ( );
end top_tb;

architecture Behavioral of top_tb is

    constant clock_period: time := 10 ns;
    signal clock: std_logic := '0';
    signal reset: std_logic := '0';

    signal vs: std_logic := '0';
    signal hs: std_logic := '0';
    signal r: std_logic_vector(3 downto 0) := "0000";
    signal g: std_logic_vector(3 downto 0) := "0000";
    signal b: std_logic_vector(3 downto 0) := "0000";


begin

    clk: process
    begin
        wait for clock_period/2;
        clock <= not clock;
    end process;


    uut: entity work.top(Behavioral)
        port map( CLK100MHZ => clock,
                 CPU_RESETN => reset,
                 VGA_HS =>  hs,
                 VGA_VS =>  vs,
                 VGA_R => r,
                 VGA_G => g,
                 VGA_B =>  b
                );


    stimuli: process
    begin
        reset <= '0';
        wait for 2*clock_period;
        reset <= '1';
        wait for 2*clock_period;

--        wait for 15*clock_period;
        wait; -- wait forever ...
    end process;
end Behavioral;

