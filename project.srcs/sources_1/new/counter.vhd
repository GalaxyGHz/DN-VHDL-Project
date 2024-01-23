----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity counter is
    generic (
        n : positive -- bitna sirina stevca
    );
    port (
        clock        : in std_logic;
        reset        : in std_logic;
        clock_enable : in std_logic;
        count_up     : in std_logic;
        count_down   : in std_logic;
        star         : in std_logic;
        collision    : in std_logic;
        value        : out unsigned(n-1 downto 0)
    );
end entity;


architecture Behavioral of counter is

    signal count : unsigned(n-1 downto 0) := (others => '0');
    signal star_old : std_logic := '0';

begin

    value <= count;
    
    process (clock)
    begin
        if rising_edge(clock) then
            if reset='1' then
                count <= (others => '0');
                star_old <= '0';
            else
                if collision = '1' then
                    count <= (others => '0');
                    
                elsif star = '1' and star_old = '0' then
                    -- add value for star
                    count <= count + 65536;
                    
                elsif clock_enable = '1' then
                    -- increment or decrement
                    if count_up='1' and count_down='0' then
                        count <= count + 1;
                    elsif count_up='0' and count_down='1' then
                        count <= count - 1;
                    end if;
                end if;
                
                star_old <= star;
            end if;
        end if;
    end process;

end Behavioral;
