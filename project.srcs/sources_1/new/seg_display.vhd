----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity seg_display is
    generic (
        refresh_period : in positive := 16e5    -- 16ms ~ frekvenca 60Hz  -- ce das default vrednost, ni treba mapirat v top modulu
    );
    port (
        clock          : in std_logic;
        reset          : in std_logic;
        value          : in unsigned(31 downto 0);
        anode_select   : out unsigned(7 downto 0);
        segment_select : out unsigned(7 downto 0)
    );
end entity;


architecture Behavioral of seg_display is
    
    -- konstante
    constant digit_refresh : integer := refresh_period / 8; -- perioda 2ms
    
    -- signali
    signal anodes   : unsigned(7 downto 0) := "11111110";
    signal segments : unsigned(7 downto 0);
    signal digit    : unsigned(3 downto 0);
    signal CE       : std_logic;
    
    -- da reset mal lepse zgleda
    signal old_reset : std_logic := '0';
    
begin

    -- output anodes
    anode_select <= "00000000" when reset='1' else anodes;
    segment_select <= "10111111" when reset='1' else segments;

    -- value_to_digit
    with anodes select
        digit <= value (3 downto 0)   when "11111110",
                 value (7 downto 4)   when "11111101",
                 value (11 downto 8)  when "11111011",
                 value (15 downto 12) when "11110111",
                 value (19 downto 16) when "11101111",
                 value (23 downto 20) when "11011111",
                 value (27 downto 24) when "10111111",
                 value (31 downto 28) when "01111111",
                 value (3 downto 0)   when others;
    
    -- digit_to_segments
    with digit select
        segments <= "11000000" when "0000", -- 0
                    "11111001" when "0001", -- 1
                    "10100100" when "0010", -- 2
                    "10110000" when "0011", -- 3
                    "10011001" when "0100", -- 4
                    "10010010" when "0101", -- 5
                    "10000010" when "0110", -- 6
                    "11111000" when "0111", -- 7
                    "10000000" when "1000", -- 8
                    "10010000" when "1001", -- 9
                    "10001000" when "1010", -- A
                    "10000011" when "1011", -- B
                    "11000110" when "1100", -- C
                    "10100001" when "1101", -- D
                    "10000110" when "1110", -- E
                    "10001110" when "1111"; -- f
    
    -- instanciranje prescaler modula
    prescaler: entity work.prescaler
    generic map(
        max_period => digit_refresh
    )
    port map(
        clock => clock,
        reset => reset,
        period => digit_refresh,
        clock_enable => CE
    );
    
    process (clock)
    begin
        if rising_edge(clock) then
            if old_reset='0' and reset='1' then     -- rising edge of reset
                anodes <= "00000000";
                old_reset <= '1';
            elsif old_reset='1' and reset='0' then  -- falling edge of reset
                anodes <= "11111110";
                old_reset <= '0';
            else
                if CE='1' then
                    anodes <= rotate_left(anodes, 1);
                end if;
            end if;
            old_reset <= reset;
        end if;
    end process;

end Behavioral;
