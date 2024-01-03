----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity drawer is
    Port (
        clock : in std_logic;
        display_area : in STD_LOGIC;
        column : in natural range 0 to 1279;
        row : in natural range 0 to 1023;
        spaceship_pos_x : in natural range 0 to 1279;
        spaceship_pos_y : in natural range 0 to 1023;
        vga_r : out STD_LOGIC_VECTOR (3 downto 0);
        vga_g : out STD_LOGIC_VECTOR (3 downto 0);
        vga_b : out STD_LOGIC_VECTOR (3 downto 0));
end drawer;

architecture Behavioral of drawer is

    signal address : integer range 0 to 2000;
    signal data : std_logic_vector(11 downto 0);

    signal display_spaceship : std_logic;

begin
    
    -- Do we draw the spaceship
    display_spaceship <= '1' when display_area='1' and row >= spaceship_pos_y - 16 and row <= spaceship_pos_y + 16 and
 column >= spaceship_pos_x - 16 and column <= spaceship_pos_x + 16 else '0';

    -- Image is stored here
    spaceshipROM: entity work.spaceshipROM(Behavioral)
        port map (
            clock => clock,
            address => address,
            data => data
        );

    -- Temporary drawing location, used for testing
    process (display_area, row, column)
    begin
        -- White edge
        if display_area='1' and (row=0 or row=2 or row=1021 or row=1023 or column=0 or column=2 or column=1279 or column=1277) then
            vga_r <= "1111";
            vga_g <= "1111";
            vga_b <= "1111";
        elsif display_spaceship = '1' then
            vga_r <= data(11 downto 8);
            vga_g <= data(7 downto 4);
            vga_b <= data(3 downto 0);
        else
            vga_r <= "0000";
            vga_g <= "0000";
            vga_b <= "0000";
        end if;
    end process;

    process (clock, display_spaceship)
    begin
        if rising_edge(clock) then
            if display_spaceship = '1' then
                if row = spaceship_pos_y - 16 and column = spaceship_pos_x - 16 then
                    address <= 0;
                else
                    address <= address + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
