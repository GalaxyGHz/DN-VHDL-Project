----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spaceship_obj is
    port (
        clock        : in std_logic;
        reset        : in std_logic;
        display_area : in std_logic;
        column       : in natural range 0 to 1279;
        row          : in natural range 0 to 1023;
        pos_x        : in natural range 0 to 1279;
        pos_y        : in natural range 0 to 1023;
        valid        : out std_logic;
        data         : out std_logic_vector(11 downto 0)
    );
end spaceship_obj;

architecture Behavioral of spaceship_obj is

    signal ROM_address : integer range 0 to 1088;

begin

    spaceshipROM: entity work.spaceshipROM(Behavioral)
        port map (
            clock => clock,
            address => ROM_address,
            data => data
        );
        
    update_ROM_address: process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                ROM_address <= 0;
            elsif display_area='1' then
                if row = 0 and column = 0 then
                    ROM_address <= 0;
                end if;
                
                if row >= pos_y - 16 
                    and row <= pos_y + 16 
                    and column >= pos_x - 16 
                    and column <= pos_x + 16 
                then
                    if ROM_address = 1088 then -- number of pixels in spaceship image is 1089
                        ROM_address <= 0;
                    else
                        ROM_address <= ROM_address + 1;
                    end if;
                    valid <= '1';
                else
                    valid <= '0';
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;
