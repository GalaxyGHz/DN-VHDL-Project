----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity microphone is
    port (
        clock   : in std_logic;
        reset   : in std_logic;
        
        SW      : in std_logic_vector(1 downto 0);
        LED     : out std_logic_vector(15 downto 0);
        
        M_DATA  : in std_logic;
        M_CLK   : out std_logic;
        M_LRSEL : out std_logic;
        
        value   : out unsigned(31 downto 0)
    );
end microphone;


architecture Behavioral of microphone is
    
    constant mic_period : positive := 54;            -- 108 MHz / 54 = 2 MHz
    constant sampler_max_period : positive := 108e6; -- 108 MHz / 108M = 1 Hz
    
    signal mic_clk : std_logic := '0';
    signal mic_clk_edge : std_logic;
    
    signal sampler_period : positive;
    signal sampler_en : std_logic;
    
    signal bits : std_logic_vector(31 downto 0) := (others => '0');

begin

    M_CLK <= mic_clk;
    M_LRSEL <= '0';
    
    -- nastavitev frekvence vzorcenja
    sampler_period <= sampler_max_period when SW(1) = '1' else
                      sampler_max_period / 16;

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
    
    -- generiranje ure za mikrofon
    mic_clk_gen : process (clock)
    begin
        if rising_edge(clock) then
            if mic_clk_edge='1' then
                mic_clk <= not mic_clk;
            end if;
        end if;
    end process;
    
    -- zajemanje signala iz mikrofona
    mic_read : process (clock)
    begin
        if rising_edge(clock) then
            -- branje signala na fronto ure
            if mic_clk='1' and mic_clk_edge='1' then
                -- mic output is valid
                bits(31 downto 1) <= bits(30 downto 0);
                bits(0) <= M_DATA;
            end if;
            
            -- zapis na izhod
            if sampler_en='1' then
                if SW(0) = '0' then
                    led <= (others => '0');
                else
                    led <= bits(15 downto 0);
                end if;
                value <= UNSIGNED(bits);
            end if;
        end if;
    end process;
    
end Behavioral;
