----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity asteroid is
    generic (
        asteroid_pos_x : in natural range 0 to 1279;
        asteroid_pos_y : in natural range 0 to 1023
    );
    port (
        clock : in std_logic;
        reset : in std_logic;
        spaceship_pos_x : in natural range 0 to 1279;
        spaceship_pos_y : in natural range 0 to 1023;
        display_area : in std_logic;
        column : in natural range 0 to 1279;
        row    : in natural range 0 to 1023;
        valid : out std_logic;
        data : out std_logic_vector(11 downto 0)
    );
end asteroid;

architecture Behavioral of asteroid is

    signal ROM_address : integer range 0 to 4000;

begin

    -- Do we draw the asteroid
    valid <= '1' when display_area='1' 
                  and row >= asteroid_pos_y - 30 
                  and row <= asteroid_pos_y + 29 
                  and column >= asteroid_pos_x - 30 
                  and column <= asteroid_pos_x + 29 
                 else '0';

    asteroidROM: entity work.asteroidROM(Behavioral)
        port map (
            clock => clock,
            address => ROM_address,
            data => data
        );

end Behavioral;
