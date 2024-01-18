----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity random is
    port (
        clock  : in std_logic;
        reset  : in std_logic;
        
        SW : in std_logic_vector(3 downto 0);
        LED : out std_logic_vector(15 downto 0);
        
        M_DATA  : in std_logic;
        M_CLK   : out std_logic;
        M_LRSEL : out std_logic;
        
        value : out unsigned (31 downto 0)
    );
end entity;


architecture Behavioral of random is
    
    -- konstante
    constant display_refresh_period : positive := 16e5; -- 16ms na 8 LEDic = frekvenca ~16Hz
    
    -- signali

begin
    
    -- instanciranje modula microphone
    mic : entity work.microphone
    port map(
        clock => clock,
        reset => reset,
        led => LED,
        sw => SW,
        M_DATA => M_DATA,
        M_CLK => M_CLK,
        M_LRSEL => M_LRSEL,
        value => value
    );
    
end Behavioral;
