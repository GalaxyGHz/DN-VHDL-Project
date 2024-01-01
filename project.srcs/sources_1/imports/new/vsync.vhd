----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity vsync is
    Port ( 
        clock : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        clock_enable : in STD_LOGIC;
        display_area : inout STD_LOGIC;
        row          : out natural range 0 to 1023;
        vsync : out STD_LOGIC);
end entity;

architecture Behavioral of vsync is

constant T  : integer := 1066; -- Number of lines
constant SP : integer := 3;  -- Wait time
constant FP : integer := 1;  -- Front porch
constant BP : integer := 38;  -- Back porch

signal count : integer range 0 to T-1 := 0;
signal sync_on : std_logic := '0';
signal sync_off : std_logic := '0';
signal reset_count : std_logic := '0';
signal q : std_logic := '0';

begin
        
    -- Comparator
    sync_on  <= '1' when count = SP-1 and clock_enable='1' else '0';
    sync_off <= '1' when count = T-1 and clock_enable='1' else '0';
    
    -- Reset signal
    reset_count <= reset OR sync_off;
    
    -- preslikava stanja pomnilne celice na izhod
    vsync <= q;
    
    -- Are we in the drawable screen
    display_area <= '1' when count >= (SP + BP) AND count < (T - FP) else '0';
    
    -- Find pixel row
    row <= (count - SP - BP) when display_area ='1' else 0;
       
    counter: process (clock)
    begin      
        if rising_edge(clock) then
            if reset_count = '1' then
                count <= 0;
            else
                if clock_enable = '1' then
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;
    
    SR_FF: process (clock)
    begin            
        if rising_edge(clock) then
            if reset = '1' then
                q <= '0';
            elsif sync_on = '1' then
                q <= '1';
            elsif sync_off = '1' then
                q <= '0';                      
            end if;
        end if;
    end process;

end Behavioral;
