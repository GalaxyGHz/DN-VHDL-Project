----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hsync is
    Port ( 
        clock : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        clock_enable : out STD_LOGIC;
        display_area : inout STD_LOGIC;
        column       : out natural range 0 to 1279;
        hsync : out STD_LOGIC);
end entity;

architecture Behavioral of hsync is

constant T  : integer := 1688; -- hsync period signal
constant SP : integer := 112;  -- Wait time
constant FP : integer := 48;  -- Front porch
constant BP : integer := 248;  -- Back porch

signal count : integer range 0 to T-1 := 0;
signal sync_on : std_logic := '0';
signal sync_off : std_logic := '0';
signal reset_count : std_logic := '0';
signal q : std_logic := '0';

begin

    sync_on  <= '1' when count = SP-1 else '0';
    sync_off <= '1' when count = T-1 else '0';
    
    -- Reset signal
    reset_count <= reset OR sync_off;
    
    -- Output
    hsync <= q;
    
    -- End of line
    clock_enable <= sync_off;
    
    -- Are we inside the drawable screen
    display_area <= '1' when count >= (SP + BP) AND count < (T - FP) else '0';
    
    -- Find pixel column
    column <= (count - SP - BP) when display_area ='1' else 0;
    
    counter: process (clock)
    begin
        if rising_edge(clock) then
            if reset_count = '1' then
                count <= 0;
            else
                count <= count + 1;
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
