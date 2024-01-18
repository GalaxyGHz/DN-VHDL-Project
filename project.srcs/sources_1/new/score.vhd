----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity score is
    Port ( 
        clock : in std_logic;
        reset : in std_logic;
        star  : in std_logic;
        AN    : out unsigned(7 downto 0);
        SEG   : out unsigned(7 downto 0)
    );
end score;


architecture Behavioral of score is

    constant max_period  : positive := 108e6 / 2; -- 4x na sekundo
    constant counter_width  : positive := 32;
    constant display_refresh_period : positive := 16e5; -- 16ms na 8 LEDic = frekvenca ~16Hz
    
    signal prescaler_period : positive;
    signal CE : std_logic;
    signal counter_value : unsigned(counter_width-1 downto 0);

begin

    prescaler_period <= max_period / 2;
    
    -- instanciranje modula prescaler
    prescaler : entity work.prescaler
    generic map(
        max_period => max_period
    )
    port map(
        clock        => clock,
        reset        => RESET,
        period       => prescaler_period,
        clock_enable => CE
    );
    
    -- instanciranje modula counter
    counter : entity work.counter
    generic map(
        n => counter_width
    )
    port map(
        clock        => clock,
        reset        => reset,
        clock_enable => CE,
        count_up     => '1',
        count_down   => '0',
        star         => star,
        value        => counter_value
    );
    
    -- instanciranje modula seg_display
    seven_seg : entity work.seg_display
    generic map(
        refresh_period => display_refresh_period
    )
    port map(
        clock          => clock,
        reset          => reset,
        value          => counter_value,
        anode_select   => AN,
        segment_select => SEG
    );

end Behavioral;
