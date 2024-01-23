----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity drawer is
    Port (
        clock : in std_logic;
        reset : in std_logic;
        display_area : in std_logic;
        rand_value   : in unsigned (31 downto 0);
        column : in natural range 0 to 1279;
        row    : in natural range 0 to 1023;
        spaceship_pos_x : in natural range 0 to 1279;
        spaceship_pos_y : in natural range 0 to 1023;
        vga_r : out std_logic_vector (3 downto 0);
        vga_g : out std_logic_vector (3 downto 0);
        vga_b : out std_logic_vector (3 downto 0);
        star  : out std_logic;
        collision : out std_logic
    );
end drawer;

architecture Behavioral of drawer is
    
    signal data : std_logic_vector(11 downto 0);
    
    signal display_spaceship : std_logic;
    signal spaceship_data : std_logic_vector(11 downto 0);
    
    signal display_star : std_logic;
    signal star_data : std_logic_vector(11 downto 0);
    signal star_pos_x : natural range 0 to 1279 := 640;
    signal star_pos_y : natural range 0 to 1023 := 200;
    
    signal display_asteroid : std_logic;
    signal display_a1 : std_logic;
    signal display_a2 : std_logic;
    signal display_a3 : std_logic;
    signal display_a4 : std_logic;
    signal display_a5 : std_logic;
    signal display_a6 : std_logic;
    signal display_a7 : std_logic;
    signal data_a1    : std_logic_vector(11 downto 0);
    signal data_a2    : std_logic_vector(11 downto 0);
    signal data_a3    : std_logic_vector(11 downto 0);
    signal data_a4    : std_logic_vector(11 downto 0);
    signal data_a5    : std_logic_vector(11 downto 0);
    signal data_a6    : std_logic_vector(11 downto 0);
    signal data_a7    : std_logic_vector(11 downto 0);
    

begin
    
    -- Do we draw an asteroid (used for collision detection)
    display_asteroid <= '1' when display_a1 = '1' 
                              or display_a2 = '1'
                              or display_a3 = '1'
                              or display_a4 = '1'
                              or display_a5 = '1'
                              or display_a6 = '1'
                              or display_a7 = '1'
                            else '0';
    
    -- Selecting data to display
    data <= spaceship_data when display_spaceship = '1' else
            data_a1        when display_a1        = '1' else
            data_a2        when display_a2        = '1' else
            data_a3        when display_a3        = '1' else
            data_a4        when display_a4        = '1' else
            data_a5        when display_a5        = '1' else
            data_a6        when display_a6        = '1' else
            data_a7        when display_a7        = '1' else
            star_data      when display_star      = '1' else
            "000011110000"; -- Green color for debugging
    
    -- Spaceship image module
    spaceship_obj: entity work.spaceship_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => spaceship_pos_x,
            pos_y        => spaceship_pos_y,
            valid        => display_spaceship,
            data         => spaceship_data
        );
    
    -- Star image module
    star_obj: entity work.star_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => star_pos_x,
            pos_y        => star_pos_y,
            valid        => display_star,
            data         => star_data
        );
    
    -- Asteroid image modules (7)
    a1_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 240,
            pos_y        => 130,
            valid        => display_a1,
            data         => data_a1
        );
        
    a2_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 1090,
            pos_y        => 190,
            valid        => display_a2,
            data         => data_a2
        );
        
    a3_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 520,
            pos_y        => 370,
            valid        => display_a3,
            data         => data_a3
        );
        
    a4_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 870,
            pos_y        => 520,
            valid        => display_a4,
            data         => data_a4
        );
        
    a5_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 130,
            pos_y        => 600,
            valid        => display_a5,
            data         => data_a5
        );
        
    a6_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 1100,
            pos_y        => 750,
            valid        => display_a6,
            data         => data_a6
        );
        
    a7_obj: entity work.asteroid_obj(Behavioral)
        port map (
            clock        => clock,
            reset        => reset,
            display_area => display_area,
            column       => column,
            row          => row,
            pos_x        => 370,
            pos_y        => 880,
            valid        => display_a7,
            data         => data_a7
        );
        
    -- Selecting what to draw
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
    
    -- Star collection and asteroid collision detection
    game_logic: process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                star_pos_x <= 640;
                star_pos_y <= 200;
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

end Behavioral;
