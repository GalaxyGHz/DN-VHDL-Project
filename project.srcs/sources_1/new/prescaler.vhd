----------------------------------------------------------------------------------
-- Delilnik ure: modul, ki zniza frekvenco ure in aktivira signal clock_enable
--               glede na podano periodo (perioda je podana genericno, da se
--               lahko modul optimizira in uporabi minimalno bitno sirino stevca
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity prescaler is
    generic(
        max_period : in positive
    );
    port(
        clock        : in std_logic;
        reset        : in std_logic;
        period       : in positive range 1 to max_period;
        clock_enable : out std_logic
    );
end entity;


architecture Behavioral of prescaler is

    signal count : natural range 0 to max_period := 0;
    
begin
    
    process (clock)
    begin
        if rising_edge(clock) then
            if reset='1' then
                count <= 0;
                clock_enable <= '0';
            else
                if count >= period - 1 then
                    count <= 0;
                    clock_enable <= '1';
                else
                    count <= count + 1;
                    clock_enable <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
