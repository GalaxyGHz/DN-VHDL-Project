----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI is
    port
(
        clk108mhz  : in STD_LOGIC;
        reset      : in STD_LOGIC;
        -- Data signals
        data_in    : in STD_LOGIC_VECTOR (7 downto 0);
        data_out   : out STD_LOGIC_VECTOR (7 downto 0);
        start      : in STD_LOGIC;
        done       : out STD_LOGIC;
        hold_ss    : in STD_LOGIC;
        --SPI Interface Signals
        sclk       : out STD_LOGIC;
        mosi       : out STD_LOGIC;
        miso       : in STD_LOGIC;
        ss         : out STD_LOGIC
    );
end SPI;

architecture Behavioral of SPI is

    constant clk108mhz_frequency : integer:= 108000000;
    constant sclk_frequency : integer:= 1000000;

    -- Internal sclk signals
    constant limit : integer := ((clk108mhz_frequency / ( 2 * sclk_frequency)) - 1);
    signal counter : integer range 0 to limit := 0;
    signal sclk_edge : std_logic := '0';
    signal sclk_internal : std_logic := '0';
    signal sclk_enable : std_logic := '0';
    signal ss_enable : std_logic := '0';

    -- Enable signals enabling shift and data in and out
    signal shift_enable : std_logic := '0';
    signal data_out_enable : std_logic :='0';
    signal data_in_enable : std_logic := '0';

    -- Shift enables for rising and falling edges of sclk
    signal rising_edge_shift : std_logic;
    signal falling_edge_shift : std_logic;

    -- State machine signals
    signal start_shifting : std_logic := '0';
    signal finish_shifting : std_logic := '0';
    signal bit_count : integer range 0 to 7 := 0;
    signal reset_counters : std_logic;

    -- Shift registers
    signal mosi_register : std_logic_vector(7 downto 0) := X"00";
    signal miso_register : std_logic_vector(7 downto 0) := X"00";

    -- Delayed with one clock period after data is assigned for stability
    signal delayed_stable_done : std_logic := '0';

    -- Control signals and states. 5:data_in_enable, 4:shift_enable, 3:reset_counters, 2:sclk_enable 1:ss_enable 0:data_out_enable
    constant state_idle : std_logic_vector(5 downto 0) := "101000";
    constant state_prepare : std_logic_vector(5 downto 0) := "000010";
    constant state_shift : std_logic_vector(5 downto 0) := "010110";
    constant state_done : std_logic_vector(5 downto 0) := "000011";

    --State signals
    signal current_state, next_state : std_logic_vector(5 downto 0) := state_idle;

    --Force user encoding for the state machine ?
    attribute FSM_ENCODING : string;
    attribute FSM_ENCODING of current_state : signal is "USER";

begin

    -- Assign all of the needed signals
    data_in_enable <= current_state(5);
    shift_enable <= current_state(4);
    reset_counters <= current_state(3);
    sclk_enable <= current_state(2);
    ss_enable <= current_state(1);
    data_out_enable <= current_state(0);

    ss <= '0' when reset = '0' and (hold_ss = '1' or ss_enable = '1') else '1';
    mosi <= mosi_register(7);
    sclk <= sclk_internal when sclk_enable = '1' else '0';

    -- If data is enabled set output to read data
    process (clk108mhz, data_out_enable, miso_register)
    begin
        if rising_edge(clk108mhz) then
            if data_out_enable = '1' then
                data_out <= miso_register;
            end if;
        end if;
    end process;

    -- Set done with dealy of one clock period
    process (clk108mhz, data_out_enable, delayed_stable_done)
    begin
        if rising_edge(clk108mhz) then
            delayed_stable_done <= data_out_enable;
            done   <= delayed_stable_done;
        end if;
    end process;

    -- Prescaler to generate signal on rising and falling egde of sclk
    process (clk108mhz, reset_counters, counter)
    begin
        if rising_edge(clk108mhz) then
            if reset_counters = '1' or counter=  limit then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- sclk edge signal
    sclk_edge <= '1' when counter = limit else '0';

    -- Create sclk internal from sclk edge
    process (clk108mhz, reset_counters, sclk_edge, sclk_internal)
    begin
        if rising_edge(clk108mhz) then
            if reset_counters = '1' then
                sclk_internal <= '0';
            elsif sclk_edge = '1' then
                sclk_internal <= not sclk_internal;
            end if;
        end if;
    end process;

    -- Rising and falling egde sifts, at RE mosi is read, at FE next bit is shifted out

    rising_edge_shift  <= '1' when shift_enable = '1' and sclk_internal = '0' and sclk_edge = '1' else '0';
    falling_edge_shift <= '1' when shift_enable = '1' and sclk_internal = '1' and sclk_edge = '1' else '0';

    -- Shift bit in
    process (clk108mhz, rising_edge_shift, miso_register)
    begin
        if rising_edge(clk108mhz) then
            if rising_edge_shift = '1' then
                miso_register (7 downto 0) <= miso_register (6 downto 0) & miso;
            end if;
        end if;
    end process;

    -- Shift bit out, read data continually in idle state
    process (clk108mhz, data_in_enable, data_in, falling_edge_shift, mosi_register)
    begin
        if rising_edge(clk108mhz) then
            if data_in_enable = '1' then
                mosi_register <= data_in;
            elsif falling_edge_shift = '1' then
                mosi_register (7 downto 0) <= mosi_register (6 downto 0) & '0';
            end if;
        end if;
    end process;

    -- Increment bit count for every bit shifted out
    process (clk108mhz, reset_counters, falling_edge_shift, bit_count)
    begin
        if rising_edge(clk108mhz) then
            if reset_counters = '1' then
                bit_count <= 0;
            elsif falling_edge_shift = '1' then
                if bit_count = 7 then
                    bit_count <= 0;
                else
                    bit_count <= bit_count + 1;
                end if;
            end if;
        end if;
    end process;

    -- Assign the state machine internal signals
    start_shifting <= '1' when current_state = state_prepare and (hold_ss = '1' or (sclk_internal = '1' and sclk_edge = '1')) else '0';
    finish_shifting <= '1' when current_state = state_shift and bit_count = 7 and sclk_internal = '1' and sclk_edge = '1' else '0';

    -- State machine transition processes
    process (clk108mhz, reset, next_state)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                current_state <= state_idle;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    process (current_state, start, start_shifting, finish_shifting)
    begin
        next_state <= current_state;
        case current_state is
            when state_idle => if start = '1' then next_state <= state_prepare; end if;
            when state_prepare => if start_shifting = '1' then next_state <= state_shift; end if;
            when state_shift => if finish_shifting = '1' then next_state <= state_done; end if;
            when state_done => next_state <= state_idle;
            when others => next_state <= state_idle;
        end case;
    end process;

end Behavioral;
