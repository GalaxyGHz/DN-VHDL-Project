----------------------------------------------------------------------------------
--  
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity microphone is
    port (
        clock   : in std_logic;
        reset   : in std_logic;
        sw      : in std_logic_vector(3 downto 0);
        led     : out std_logic_vector(15 downto 0);
        M_DATA  : in std_logic;
        M_CLK   : out std_logic;
        M_LRSEL : out std_logic;
        value   : out unsigned(31 downto 0)
    );
end microphone;


architecture Behavioral of microphone is
    
    constant mic_period : positive := 54;   -- 108 MHz / 54 = 2 MHz
    constant sampler_max_period : positive := 10000000; -- 2 MHz / 10M = 1x na 5 sekund
    
    signal mic_clk : std_logic := '0';
    signal mic_clk_edge : std_logic;
    
    signal sampler_period : positive;
    signal sampler_en : std_logic;
    
    signal index : unsigned(3 downto 0) := (others => '0'); -- 4bit -> 16 vrednosti
    signal bits : std_logic_vector(15 downto 0) := (others => '0');
--    signal index : unsigned(4 downto 0) := (others => '0');   -- 5bit -> 32 vrednosti
--    signal bits : std_logic_vector(31 downto 0) := (others => '0');

begin

    M_CLK <= mic_clk;
    M_LRSEL <= '0';
    led <= bits;
    value(31 downto 16) <= (others => '0');
    value(15 downto 0) <= unsigned(bits);
--    led <= bits(15 downto 0);
--    value <= bits;
    
    -- nastavitev frekvence vzorcenja
    sampler_period <= sampler_max_period / 2  when sw = "0001" else
                      sampler_max_period / 4  when sw = "0010" else
                      sampler_max_period / 8  when sw = "0100" else
                      sampler_max_period / 16 when sw = "1000" else
                      sampler_max_period;

    -- instanciranje prescaler modula za 1MHz uro
    mic_1MHz_clk : entity work.prescaler
    generic map (
        max_period => mic_period
    )
    port map (
        clock => clock,
        reset => reset,
        period => mic_period,
        clock_enable => mic_clk_edge
    );
    
    -- instanciranje prescaler modula za vzorcenje
    sampler : entity work.prescaler
    generic map (
        max_period => sampler_max_period
    )
    port map (
        clock => clock,
        reset => reset,
        period => sampler_period,
        clock_enable => sampler_en
    );
    
    -- ura za mikrofon
    process (clock)
    begin
        if rising_edge(clock) then
        
            if mic_clk_edge='1' then
                mic_clk <= not mic_clk;
                if mic_clk='1' then
                    -- mic output is valid
                    
                    if sampler_en='1' or index > 0 then
                        bits(to_integer(index)) <= M_DATA;
                        index <= index + 1;
                    end if;
                      
                end if;
            end if;
            
        end if;
    end process;

end Behavioral;
