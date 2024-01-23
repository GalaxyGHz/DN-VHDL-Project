----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity drawer is
    Port (
        clock : in std_logic;
        reset : in std_logic;
        display_area : in std_logic;
        rand_value : in unsigned (31 downto 0);
        column : in natural range 0 to 1279;
        row    : in natural range 0 to 1023;
        spaceship_pos_x : in natural range 0 to 1279;
        spaceship_pos_y : in natural range 0 to 1023;
        vga_r : out STD_LOGIC_VECTOR (3 downto 0);
        vga_g : out STD_LOGIC_VECTOR (3 downto 0);
        vga_b : out STD_LOGIC_VECTOR (3 downto 0);
        star  : out std_logic;
        collision : out std_logic
    );
end drawer;

architecture Behavioral of drawer is
    
    signal data : std_logic_vector(11 downto 0);
    
    signal display_spaceship : std_logic;
    signal spaceship_ROM_address : integer range 0 to 2000;
    signal spaceship_data : std_logic_vector(11 downto 0);
    
    signal display_star : std_logic;
    signal star_ROM_address : integer range 0 to 8000;
    signal star_data : std_logic_vector(11 downto 0);
    signal star_pos_x : natural range 0 to 1279 := 640;
    signal star_pos_y : natural range 0 to 1023 := 400;
    
    signal display_asteroid : std_logic;
    signal display_a1 : std_logic;
    signal display_a2 : std_logic;
    signal data_a1    : std_logic_vector(11 downto 0);
    signal data_a2    : std_logic_vector(11 downto 0);
    

begin
    
    -- Do we draw the spaceship
    display_spaceship <= '1' when display_area='1' 
                              and row >= spaceship_pos_y - 16 
                              and row <= spaceship_pos_y + 16 
                              and column >= spaceship_pos_x - 16 
                              and column <= spaceship_pos_x + 16 
                             else '0';
    
    -- Do we draw the star
    display_star <= '1' when display_area='1' 
                         and row >= star_pos_y - 42 
                         and row <= star_pos_y + 42 
                         and column >= star_pos_x - 42 
                         and column <= star_pos_x + 42 
                        else '0';
    
    -- Do we draw an asteroid (used for collision detection)
    display_asteroid <= '1' when display_a1 = '1' 
                              or display_a2 = '1'
                            else '0';
    
    -- Selecting data to display
    data <= spaceship_data when display_spaceship = '1' else
            data_a1        when display_a1        = '1' else
            data_a2        when display_a2        = '1' else
            star_data      when display_star      = '1' else
            "000011110000"; -- zelena barva za debug

    -- Spaceship image
    spaceshipROM: entity work.spaceshipROM(Behavioral)
        port map (
            clock => clock,
            address => spaceship_ROM_address,
            data => spaceship_data
        );
    
    -- Star image
    starROM: entity work.starROM(Behavioral)
        port map (
            clock => clock,
            address => star_ROM_address,
            data => star_data
        );
    
    -- Asteroid module
    a1: entity work.asteroid(Behavioral)
        generic map (
            asteroid_pos_x => 100,
            asteroid_pos_y => 200
        )
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            valid        => display_a1,
            data         => data_a1
        );
        
    a2: entity work.asteroid(Behavioral)
        generic map (
            asteroid_pos_x => 1000,
            asteroid_pos_y => 800
        )
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            valid        => display_a2,
            data         => data_a2
        );
    
    -- Temporary drawing location, used for testing
    draw_objects: process (clock)
    begin
        if rising_edge(clock) then
            if display_area='1' 
                and (row=0 or row=2 or row=1021 or row=1023 or column=0 or column=2 or column=1279 or column=1277) 
            then
                -- White border
                vga_r <= "1111";
                vga_g <= "1111";
                vga_b <= "1111";
            elsif display_spaceship = '1' or display_star = '1' or display_asteroid = '1' then
                -- Objects from ROM
                vga_r <= data(11 downto 8);
                vga_g <= data(7 downto 4);
                vga_b <= data(3 downto 0);
            else
                -- Black background
                vga_r <= "0000";
                vga_g <= "0000";
                vga_b <= "0000";
            end if;
        end if;
    end process;
    
    game_logic: process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                star_pos_x <= 640;
                star_pos_y <= 400;
                star <= '0';
            else
                -- Collect and move the star
                if display_spaceship = '1' and display_star = '1' then
                    star <= '1';
                    
                    -- generate new x
                    if rand_value(10 downto 0) < 46 then
                        star_pos_x <= TO_INTEGER(rand_value(10 downto 0) + 46);
                    elsif rand_value(10 downto 0) > 1234 then
                        star_pos_x <= TO_INTEGER(rand_value(10 downto 0) - 1234 + 46);
                    else
                        star_pos_x <= TO_INTEGER(rand_value(10 downto 0));
                    end if;
                    
                    -- generate new y
                    if rand_value(20 downto 11) < 46 then
                        star_pos_y <= TO_INTEGER(rand_value(20 downto 11) + 46);
                    elsif rand_value(20 downto 11) > 978 then
                        star_pos_y <= TO_INTEGER(rand_value(20 downto 11) - 978 + 46);
                    else
                        star_pos_y <= TO_INTEGER(rand_value(20 downto 11));
                    end if;
                    
                else 
                    star <= '0';
                end if;
                
                -- Collision with asteroid
                if display_spaceship = '1' and display_asteroid = '1' then
                    collision <= '1';
                else
                    collision <= '0';
                end if;
            end if;
        end if;
    end process;

    update_ROM_addresses: process (clock)
    begin
        if rising_edge(clock) then
            if display_area = '1' and row = 0 and column = 0 then
                spaceship_ROM_address <= 0;
                star_ROM_address <= 0;
            end if;
            
            if display_spaceship = '1' then
                if spaceship_ROM_address = 1088 then -- number of pixels in spaceship image is 1089
                    spaceship_ROM_address <= 0;
                else
                    spaceship_ROM_address <= spaceship_ROM_address + 1;
                end if;
            end if;
            
            if display_star = '1' then
                if star_ROM_address = 7224 then -- number of pixels in star image is 7225
                    star_ROM_address <= 0;
                else
                    star_ROM_address <= star_ROM_address + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
