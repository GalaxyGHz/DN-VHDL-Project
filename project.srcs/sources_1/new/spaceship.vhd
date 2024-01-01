----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_signed.all;

entity spaceship is
    Port ( clk108mhz : in STD_LOGIC;
         reset : in STD_LOGIC;
         -- Accelerometer data
         accel_x : in STD_LOGIC_VECTOR (9 downto 0);
         accel_y : in STD_LOGIC_VECTOR (9 downto 0);
         accel_ready : in std_logic;
         -- Spaceship position
         spaceship_pos_x : out natural range 0 to 1279;
         spaceship_pos_y : out natural range 0 to 1023
        );
end spaceship;

architecture Behavioral of spaceship is

    constant start_x : natural := 900;
    constant start_y : natural  := 1023;

    -- Prescaler constants
    constant limit: integer := 1e8 - 1;
    signal count : integer range 0 to limit := 0;
    -- How many times per second to update spaceship position, currently 60
    signal updates_per_sec : integer range 0 to limit :=  limit/60;
    signal clock_enable : std_logic;

    -- Spaceship position
    signal pos_x : natural range 0 to 1279 := start_x;
    signal pos_y : natural range 0 to 1023 := start_y;

    -- Spaceship speed, calculated by transforming accelerometer data
    signal speed_x : integer range -511 to 512 := 0;
    signal speed_y : integer range -511 to 512 := 0;

begin

    spaceship_pos_x <= pos_x;
    spaceship_pos_y <= pos_y;
    
    -- Transform accelerometer data into spaceship speed
    process (clk108mhz)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
              speed_x <= 0;
              speed_y <= 0;
            else 
                if accel_ready = '1' then
                    speed_x <= (to_integer(unsigned(accel_x)) - 511) / 10;
                    speed_y <= (to_integer(unsigned(accel_y)) - 511) / 10;
                end if;
            end if;
        end if;
    end process;

    -- Calculate new spaceship position
    process (clk108mhz)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                pos_x <= start_x;
                pos_y <= start_y;
            else
                if clock_enable = '1' then -- 3 is the border width, 16 the spaceship size (33x33)
                    -- Horizontal limits
                    if (pos_x + speed_x) >= 1279 - 3 - 16 then
                        pos_x <= 1279 - 3 - 16;
                    elsif (pos_x + speed_x) <= 0 + 3 + 16 then
                        pos_x <= 0 + 3 + 16;
                    else 
                        pos_x <= pos_x + speed_x;
                    end if;
                    -- Vertical limits
                    if (pos_y + speed_y) >= 1023 - 3 - 16 then
                        pos_y <= 1023 - 3 - 16;
                    elsif (pos_y + speed_y) <= 0 + 3 + 16 then
                        pos_y <= 0 + 3 + 16;
                    else 
                        pos_y <= pos_y + speed_y;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Prescaler
    process (clk108mhz)
    begin
        if rising_edge(clk108mhz) then
            if reset='1' then
                count <= 0;
                clock_enable <= '0';
            elsif count >= updates_per_sec then
                count <= 0;
                clock_enable <= '1';
            else
                clock_enable <= '0';
                count <= count + 1;
            end if;
        end if;
    end process;

end Behavioral;
