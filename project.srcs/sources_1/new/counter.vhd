----------------------------------------------------------------------------------
-- 
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
        value        : out unsigned(n-1 downto 0)
    );
end entity;


architecture Behavioral of counter is

    signal count : unsigned(n-1 downto 0) := (others => '0');

begin

    value <= count;
    
    process (clock)
    begin
        if rising_edge(clock) then
            if reset='1' then
                count <= (others => '0');
            else
                if clock_enable = '1' then
                    if count_up='1' and count_down='0' then
                        count <= count + 1;
                    elsif count_up='0' and count_down='1' then
                        count <= count - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
