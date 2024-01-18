----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_signed.all;
use IEEE.math_real.all;

entity ADXL362 is
    port
(
        clk108mhz   : in STD_LOGIC;
        reset       : in STD_LOGIC;
        -- Accelerometer data signals
        accel_x     : out STD_LOGIC_VECTOR (11 downto 0);
        accel_y     : out STD_LOGIC_VECTOR (11 downto 0);
        accel_z     : out STD_LOGIC_VECTOR (11 downto 0);
        accel_temp  : out STD_LOGIC_VECTOR (11 downto 0);
        accel_ready : out STD_LOGIC;
        --SPI Interface Signals
        sclk        : out STD_LOGIC;
        mosi        : out STD_LOGIC;
        miso        : in STD_LOGIC;
        ss          : out STD_LOGIC
    );
end ADXL362;

architecture Behavioral of ADXL362 is

    constant clk108mhz_frequency : integer := 108000000;
    constant number_of_reads_average : integer := 16;
    constant update_frequency : integer := 1000;

    constant update_limit : integer := (clk108mhz_frequency / update_frequency);
    constant clk108mhz_period : integer := ((1000000000 / clk108mhz_frequency) * 1000);

    --ADXL 362 read and write commands
    constant read_command : std_logic_vector(7 downto 0) := X"0B";
    constant write_command : std_logic_vector(7 downto 0) := X"0A";
    constant read_starting_address : std_logic_vector(7 downto 0):= X"0E";
    constant status_register_address : std_logic_vector(7 downto 0):= X"0B";

    -- Number of bytes to read and write for different commands
    constant write_3_bytes_when_configuring : integer := 3;
    constant write_2_bytes_when_commanding : integer := 2;
    constant read_8_bytes_when_reading : integer := 8;
    constant read_1_byte_when_reading_status : integer := 1;

    constant number_of_command_vectors : integer := 4;

    -- Number of reads for which average is calculated, default is 16
    constant number_of_reads : natural := number_of_reads_average;
    constant extra_bits : natural := natural(ceil(log(real(number_of_reads), 2.0)));

    -- SPI inactive time
    constant ss_inactive_time : integer := (10000 / (clk108mhz_period/1000));

    attribute FSM_ENCODING : string;

    --SPI controler
    signal start :  std_logic;
    signal done :  std_logic;
    signal hold_ss : std_logic;

    type ROM_type is array (0 to ((2 * number_of_command_vectors)-1)) of std_logic_vector(7 downto 0);

    constant initialization_data : ROM_type := ( X"1F", X"52", -- Soft Reset Register Address and Reset Command
                                                 X"1F", X"00", -- Soft Reset Register Address, clear Command
                                                 X"2D", X"02", -- Power Control Register, Enable Measure Command
                                                 X"2C", X"14"  -- Filter Control Register, 2g range, 1/4 Bandwidth, 200HZ Output Data Rate                                      
                                                );

    signal initialization_data_address : integer range 0 to (number_of_command_vectors - 1) := 0;
    signal increment_address_enable :  std_logic := '0';
    signal increment_address : std_logic := '0';
    signal initialization_complete : std_logic := '0';

    type command_register_type is array (0 to 2) of std_logic_vector(7 downto 0);
    signal command_regiset : command_register_type := (X"00", X"00", write_command);

    signal load_command_register : std_logic := '0';
    signal shift_command_register : std_logic := '0';

    signal sent_bytes_count : integer range 0 to 3 := 0;
    signal load_sent_bytes_count : std_logic := '0';

    -- Reset both the sent and received byte counter
    signal reset_sent_bytes_count : std_logic := '0';

    -- SPI data signals. Reading data will be a 8-byte transfer:
    -- XACC_H, XACC_L, YACC_H, YACC_L, ZACC_H, ZACC_L, TEMP_H, TEMP_L
    type data_register_type is array (0 to (read_8_bytes_when_reading - 1)) of std_logic_vector(7 downto 0);
    signal data_register : data_register_type := (others => X"00");

    signal shift_data_register_enable : std_logic := '0';
    signal shift_data_register : std_logic := '0';

    signal received_bytes_count : integer range 0 to read_8_bytes_when_reading - 1 := 0;
    signal load_received_bytes_count : std_logic := '0';

    signal data_send : std_logic_vector(7 downto 0) := X"00";
    signal data_receive : std_logic_vector(7 downto 0) := X"00";


    signal start_spi_transfer : std_logic := '0'; -- Start SPI transfer
    signal spi_readwrite : std_logic := '0'; -- Write 3 bytes or write 2 bytes followed by read 1 byte or 8 bytes
    signal spi_write_finished : std_logic := '0'; -- Active when the write transfer is done, i.e. 2 or 3 bytes were written
    signal spi_read_finished : std_logic := '0'; -- Active when the read transfer is done, i.e. 8 bytes were read

    signal spi_sendreceive_finished : std_logic := '0';

    -- MSB: 4:reserved, 3:Shift_Cmd_Reg, 2:EN_Shift_Data_Reg, 1:SPI_SendRec_Done, 0:Start,
    constant state_send_receive_idle : std_logic_vector(4 downto 0) := "00000"; -- Idle state
    constant state_prepare_command : std_logic_vector(4 downto 0) := "01000"; -- Load data and shift the command register
    constant state_send_start_write : std_logic_vector(4 downto 0) := "00001"; -- Send the start command to SPI
    constant state_wait_on_done_write : std_logic_vector(4 downto 0) := "10000"; -- Wait until done
    constant state_send_start_read : std_logic_vector(4 downto 0) := "10001"; -- Send start command again to the SPI interface if read
    constant state_wait_on_done_read : std_logic_vector(4 downto 0) := "00100"; -- Wait until done comes
    constant state_send_receive_done : std_logic_vector(4 downto 0) := "00010"; -- Return to Idle

    signal current_state_sendreceive, next_state_send_receive : std_logic_vector(4 downto 0) := state_send_receive_idle;
    attribute FSM_ENCODING of current_state_sendreceive : signal is "USER";

    -- Inactive period
    signal ss_inactive_count : integer range 0 to (ss_inactive_time - 1) := 0;
    signal reset_ss_inactive_count : std_logic := '0';
    signal ss_inactive_count_finished : std_logic := '0';

    signal spi_transaction_finished : std_logic := '0';

    signal start_spi_transaction : std_logic := '0'; -- Start SPI transaction

    -- MSB: 7:reserved, 6:Load_Cmd_Reg, 5:Load_Cnt_Bytes_Sent, 4:Load_Cnt_Bytes_Rec, 3:StartSpiSendRec, 2:HOLD_SS, 1:Reset_Cnt_SS_Inactive, 0:SPI_Trans_Done
    constant state_transaction_idle : std_logic_vector(7 downto 0) := "00000000"; -- Idle state
    constant state_prep_and_send_command : std_logic_vector(7 downto 0) := "01111100"; -- Load command string
    constant state_wait_on_done_sendreceive : std_logic_vector(7 downto 0) := "00000110"; -- Wait for first state machine
    constant state_wait_for_ss_inactive : std_logic_vector(7 downto 0) := "10000000"; -- Wait for inactive period
    constant state_transaction_done : std_logic_vector(7 downto 0) := "00000001"; -- Return to Idle

    signal current_state_transaction, next_state_transaction : std_logic_vector(7 downto 0) := state_transaction_idle;
    attribute FSM_ENCODING of current_state_transaction : signal is "USER";

    -- Sampling rate
    signal sample_rate_counter : integer range 0 to (update_limit - 1) := 0;
    signal reset_sample_rate_counter : std_logic := '0';
    signal sample_rate_clock_enable : std_logic := '0';

    -- 16 reads will be averaged
    signal number_of_reads_counter : integer range 0 to (number_of_reads - 1) := 0;
    signal number_of_reads_clock_enable : std_logic := '0';
    signal reser_number_of_reads_counter : std_logic := '0';
    signal number_of_reads_finished : std_logic := '0';

    -- Accumulators
    signal accel_x_sum : std_logic_vector((11 + (extra_bits)) downto 0) := (others => '0');
    signal accel_y_sum : std_logic_vector((11 + (extra_bits)) downto 0) := (others => '0');
    signal accel_z_sum : std_logic_vector((11 + (extra_bits)) downto 0) := (others => '0');
    signal accel_temp_sum : std_logic_vector((11 + (extra_bits)) downto 0) := (others => '0');

    signal sum_clock_enable : std_logic := '0';
    signal delaying_data_ready : std_logic := '0';

    signal adxl_data_ready : std_logic := '0';
    signal adxl_configuration_error : std_logic := '0'; -- For configuration errors

    -- MSB: 9:reserved, 8:reserved, 7:Reset_Cnt_Bytes, 6:EN_Advance_Cmd_Reg_Addr, 5:StartSpiTr, 4:Reset_Cnt_Num_Reads, 
    -- 3:CE_Cnt_Num_Reads, 2:Reset_Sample_Rate_Div, 1:Enable_Sum, 0:Data_Ready_1
    constant state_control_idle : std_logic_vector(9 downto 0) := "0010010000"; -- Idle state wait for 10 clock periods before start
    constant state_send_reset_command : std_logic_vector(9 downto 0) := "0001100100"; -- Send the reset command
    constant state_wait_on_done_reset : std_logic_vector(9 downto 0) := "0001000000"; -- Wait for some time
    constant state_configure_remaining : std_logic_vector(9 downto 0) := "1001100100"; -- Clear the reset register and configure the remaining registers
    constant state_wait_for_sample_rate_clock_enable  : std_logic_vector(9 downto 0) := "0000010000"; -- wait until the sample time passes
    constant state_read_status : std_logic_vector(9 downto 0) := "0101100100"; -- Read the status register
    constant state_read_data : std_logic_vector(9 downto 0) := "0001100000"; -- Read data
    constant state_format_and_sum : std_logic_vector(9 downto 0) := "0000001010"; -- Store and sum the data
    constant state_read_finished : std_logic_vector(9 downto 0) := "0000000101"; -- Return to state_wait_for_sample_rate_clock_enable

    signal current_state_controller, next_state_controller : std_logic_vector(9 downto 0) := state_control_idle;
    attribute FSM_ENCODING of current_state_controller : signal is "USER";

begin

    spi: entity work.SPI(Behavioral)
        port map
(
            clk108mhz => clk108mhz,
            reset  => reset,
            data_in => data_send,
            data_out => data_receive,
            start => start,
            done => done,
            hold_ss => hold_ss,
            --SPI Interface Signals
            sclk => SCLK,
            mosi => MOSI,
            miso => MISO,
            ss => SS
        );

    shift_command_register <= current_state_sendreceive(3);
    shift_data_register_enable <= current_state_sendreceive(2);
    spi_sendreceive_finished <= current_state_sendreceive(1);
    start <= current_state_sendreceive(0);
    
    process (clk108mhz, reset, command_regiset, shift_command_register)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                data_send <= X"00";
            elsif shift_command_register = '1' then
                data_send <= command_regiset(2);
            end if;
        end if;
    end process;

    load_command_register <= current_state_transaction(6);
    load_sent_bytes_count <= current_state_transaction(5);
    load_received_bytes_count <= current_state_transaction(4);
    start_spi_transfer <= current_state_transaction(3);

    hold_ss <= current_state_transaction(2);
    reset_ss_inactive_count <= current_state_transaction(1);
    spi_transaction_finished <= current_state_transaction(0);

    reset_sent_bytes_count <= current_state_controller(7);
    increment_address_enable <= current_state_controller(6);
    start_spi_transaction <= current_state_controller(5);
    reser_number_of_reads_counter <= current_state_controller(4);
    
    number_of_reads_clock_enable <= current_state_controller(3);
    reset_sample_rate_counter <= current_state_controller(2);
    sum_clock_enable <= current_state_controller(1);
    delaying_data_ready <= current_state_controller(0);

    process (clk108mhz, command_regiset, initialization_data_address, current_state_controller, load_command_register, shift_command_register)
    begin
        if rising_edge(clk108mhz) then
            if load_command_register = '1' then
                if (current_state_controller = state_send_reset_command) or (current_state_controller = state_configure_remaining) then
                    command_regiset(2) <= write_command;
                    command_regiset(1) <= initialization_data (2 * initialization_data_address);
                    command_regiset(0) <= initialization_data ((2 * initialization_data_address) + 1);
                elsif (current_state_controller = state_read_status) then
                    command_regiset(2) <= read_command;
                    command_regiset(1) <= status_register_address;
                    command_regiset(0) <= X"00";
                elsif (current_state_controller = state_read_data) then
                    command_regiset(2) <= read_command;
                    command_regiset(1) <= read_starting_address;
                    command_regiset(0) <= X"00";
                end if;
            elsif shift_command_register = '1' then
                command_regiset(2) <= command_regiset(1);
                command_regiset(1) <= command_regiset(0);
                command_regiset(0) <= X"00";
            end if;
        end if;
    end process;

    increment_address <= increment_address_enable and spi_transaction_finished;

    process (clk108mhz, reset, initialization_data_address, current_state_controller, increment_address)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' or current_state_controller = state_control_idle then
                initialization_data_address <= 0;
            elsif increment_address = '1' then
                if initialization_data_address = (number_of_command_vectors - 1) then
                    initialization_data_address <= 0;
                else
                    initialization_data_address <= initialization_data_address + 1;
                end if;
            end if;
        end if;
    end process;

    initialization_complete <= '1' when initialization_data_address = (number_of_command_vectors - 1) else '0';

    shift_data_register <= shift_data_register_enable and done;

    process (clk108mhz, shift_data_register, data_receive, data_register)
    begin 
        if rising_edge(clk108mhz) then      
            if shift_data_register = '1' then
                data_register(1) <= data_register(0);
                data_register(2) <= data_register(1);
                data_register(3) <= data_register(2);
                data_register(4) <= data_register(3);
                data_register(5) <= data_register(4);
                data_register(6) <= data_register(5);
                data_register(7) <= data_register(6);
                data_register(0) <= data_receive;
            end if;
        end if;
    end process;

    process (clk108mhz, reset_sent_bytes_count, load_sent_bytes_count, shift_command_register, sent_bytes_count)
    begin
        if rising_edge(clk108mhz) then
            if reset_sent_bytes_count = '1' then
                sent_bytes_count <= 0;
            elsif load_sent_bytes_count = '1' then
                if (current_state_controller = state_send_reset_command) or (current_state_controller = state_configure_remaining) then
                    sent_bytes_count <= write_3_bytes_when_configuring;
                elsif (current_state_controller = state_read_status) or (current_state_controller = state_read_data) then
                    sent_bytes_count <= write_2_bytes_when_commanding;
                else
                    sent_bytes_count <= 0;
                end if;
            elsif shift_command_register = '1' then
                if sent_bytes_count = 0 then
                    sent_bytes_count <= 0;
                else
                    sent_bytes_count <= sent_bytes_count - 1;
                end if;
            end if;
        end if;
    end process;

    process (clk108mhz, reset_sent_bytes_count, load_received_bytes_count, shift_data_register, received_bytes_count)
    begin
        if rising_edge(clk108mhz) then
            if reset_sent_bytes_count = '1' then
                received_bytes_count <= 0;
            elsif load_received_bytes_count = '1' then
                if (current_state_controller = state_read_status)  then
                    received_bytes_count <= read_1_byte_when_reading_status - 1;

                elsif (current_state_controller = state_read_data) then
                    received_bytes_count <= read_8_bytes_when_reading -1;
                else
                    received_bytes_count <= 0;
                end if;

            elsif shift_data_register = '1' then
                if received_bytes_count = 0 then
                    received_bytes_count <= 0;
                else
                    received_bytes_count <= received_bytes_count - 1;
                end if;
            end if;
        end if;
    end process;

    process (clk108mhz, reset_sample_rate_counter, sample_rate_counter)
    begin
        if rising_edge(clk108mhz) then
            if reset_sample_rate_counter = '1' then
                sample_rate_counter <= 0;
            elsif sample_rate_counter = (update_limit - 1) then
                sample_rate_counter <= 0;
            else
                sample_rate_counter <= sample_rate_counter + 1;
            end if;
        end if;
    end process;

    sample_rate_clock_enable  <= '1' when sample_rate_counter = (update_limit - 1) else '0';

    process (clk108mhz, reser_number_of_reads_counter, number_of_reads_clock_enable, number_of_reads_counter)
    begin
        if rising_edge(clk108mhz) then
            if reser_number_of_reads_counter = '1' then
                number_of_reads_counter <= 0;
            elsif number_of_reads_clock_enable = '1' then
                if number_of_reads_counter = (number_of_reads - 1) then
                    number_of_reads_counter <= (number_of_reads - 1);
                else
                    number_of_reads_counter <= number_of_reads_counter + 1;
                end if;
            end if;
        end if;
    end process;

    number_of_reads_finished <= '1' when number_of_reads_counter = (number_of_reads - 1) else '0';

    process (clk108mhz, reset, reset_ss_inactive_count, ss_inactive_count)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' or reset_ss_inactive_count = '1' then
                ss_inactive_count <= 0;
            elsif ss_inactive_count = (ss_inactive_time - 1) then
                ss_inactive_count <= (ss_inactive_time - 1);
            else
                ss_inactive_count <= ss_inactive_count + 1;
            end if;
        end if;
    end process;

    ss_inactive_count_finished <= '1' when ss_inactive_count = (ss_inactive_time - 1) else '0';

    -- SPI controller state machine, it talks directly to the SPI device
    process (clk108mhz, current_state_controller)
    begin
        if rising_edge(clk108mhz) then
            if (current_state_controller = state_read_status) or (current_state_controller = state_read_data) then
                spi_readwrite <= '1';
            else
                spi_readwrite <= '0';
            end if;
        end if;
    end process;

    spi_write_finished <= '1' when sent_bytes_count = 0 and done = '1' else '0';
    spi_read_finished <= '1' when received_bytes_count = 0 and done = '1' else '0';

    process (clk108mhz, reset, next_state_send_receive)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                current_state_sendreceive <= state_send_receive_idle;
            else
                current_state_sendreceive <= next_state_send_receive;
            end if;
        end if;
    end process;

    process (current_state_sendreceive, start_spi_transfer, spi_write_finished, spi_read_finished, spi_readwrite, done)
    begin
        next_state_send_receive <= current_state_sendreceive; -- Default
        case (current_state_sendreceive) is
            when state_send_receive_idle =>
                if (start_spi_transfer = '1') then
                    next_state_send_receive <= state_prepare_command;
                end if;
            when state_prepare_command =>
                next_state_send_receive <= state_send_start_write;
            when state_send_start_write  =>
                next_state_send_receive <= state_wait_on_done_write;
            when state_wait_on_done_write =>
                if (spi_readwrite = '1') then
                    if (spi_write_finished = '1') then
                        next_state_send_receive <= state_send_start_read;
                    elsif (done = '1') then
                        next_state_send_receive <= state_prepare_command;
                    end if;
                else
                    if (spi_write_finished = '1') then
                        next_state_send_receive <= state_send_receive_done;
                    elsif (done = '1') then
                        next_state_send_receive <= state_prepare_command;
                    end if;
                end if;
            when state_send_start_read =>
                next_state_send_receive <= state_wait_on_done_read;
            when state_wait_on_done_read =>
                if (spi_read_finished = '1') then
                    next_state_send_receive <= state_send_receive_done;
                elsif (done = '1') then
                    next_state_send_receive <= state_send_start_read;
                end if;
            when state_send_receive_done =>
                next_state_send_receive <= state_send_receive_idle;
            when others =>
                next_state_send_receive <= state_send_receive_idle;
        end case;
    end process;

    -- State machine that controles the first state machine
    process (clk108mhz, reset, next_state_transaction)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                current_state_transaction <= state_transaction_idle;
            else
                current_state_transaction <= next_state_transaction;
            end if;
        end if;
    end process;

    process (current_state_transaction, start_spi_transaction, ss_inactive_count_finished, spi_sendreceive_finished)
    begin
        next_state_transaction <= current_state_transaction; -- Default
        case (current_state_transaction) is
            when state_transaction_idle =>
                if (start_spi_transaction = '1') then
                    next_state_transaction <= state_prep_and_send_command;
                end if;
            when state_prep_and_send_command =>
                next_state_transaction <= state_wait_on_done_sendreceive;
            when state_wait_on_done_sendreceive =>
                if (spi_sendreceive_finished = '1') then
                    next_state_transaction <= state_wait_for_ss_inactive;
                end if;
            when state_wait_for_ss_inactive =>
                if (ss_inactive_count_finished = '1') then
                    next_state_transaction <= state_transaction_done;
                end if;
            when state_transaction_done =>
                next_state_transaction <= state_transaction_idle;
            when others =>
                next_state_transaction <= state_transaction_idle;
        end case;
    end process;

    adxl_data_ready <= data_register(0)(0);
    adxl_configuration_error <= data_register(0)(7);

    process (clk108mhz, reset, next_state_controller)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                current_state_controller <= state_control_idle;
            else
                current_state_controller <= next_state_controller;
            end if;
        end if;
    end process;

    -- Main state machine
    process (current_state_controller, ss_inactive_count_finished, spi_transaction_finished, sample_rate_clock_enable, initialization_complete, adxl_data_ready, adxl_configuration_error, number_of_reads_finished)
    begin
        next_state_controller <= current_state_controller; -- Default
        case (current_state_controller) is
            when state_control_idle =>
                if (sample_rate_clock_enable = '1') then
                    next_state_controller <= state_send_reset_command;
                end if;
            when state_send_reset_command =>
                if (spi_transaction_finished = '1') then
                    next_state_controller <= state_wait_on_done_reset;
                end if;
            when state_wait_on_done_reset =>
                if (sample_rate_clock_enable = '1') then
                    next_state_controller <= state_configure_remaining;
                end if;
            when state_configure_remaining =>
                if ( initialization_complete = '1' and spi_transaction_finished = '1') then
                    next_state_controller <= state_wait_for_sample_rate_clock_enable;
                end if;
            when state_wait_for_sample_rate_clock_enable =>
                if (sample_rate_clock_enable = '1') then
                    next_state_controller <= state_read_status;
                end if;
            when state_read_status =>
                if spi_transaction_finished = '1' then
                    if adxl_configuration_error = '1' then
                        next_state_controller <= state_control_idle;
                    elsif adxl_data_ready = '1' then
                        next_state_controller <= state_read_data;
                    end if;
                end if;
            when state_read_data =>
                if (spi_transaction_finished = '1') then
                    next_state_controller <= state_format_and_sum;
                end if;
            when state_format_and_sum =>
                if (number_of_reads_finished = '1') then
                    next_state_controller <= state_read_finished;
                else
                    next_state_controller <= state_read_status;
                end if;
            when state_read_finished =>
                next_state_controller <= state_wait_for_sample_rate_clock_enable;
            when others =>
                next_state_controller <= state_control_idle;
        end case;
    end process;

    process (clk108mhz, reset, delaying_data_ready, sum_clock_enable, data_register, accel_x_sum, accel_y_sum, accel_z_sum, accel_temp_sum)
    begin
        if rising_edge(clk108mhz) then
            if (reset = '1' or delaying_data_ready = '1') then
                accel_x_sum <= (others => '0');
                accel_y_sum <= (others => '0');
                accel_z_sum <= (others => '0');
                accel_temp_sum <= (others => '0');
            elsif sum_clock_enable = '1' then
                accel_x_sum <= accel_x_sum + (data_register(4)((3 + (extra_bits)) downto 0) & data_register(5));
                accel_y_sum <= accel_y_sum + (data_register(6)((3 + (extra_bits)) downto 0) & data_register(7));
                accel_z_sum <= accel_z_sum + (data_register(2)((3 + (extra_bits)) downto 0) & data_register(3));
                accel_temp_sum <= accel_temp_sum + (data_register(0)((3 + (extra_bits)) downto 0) & data_register(1));
            end if;
        end if;
    end process;

    -- Output
    process (clk108mhz, reset, delaying_data_ready, accel_x_sum, accel_y_sum, accel_z_sum, accel_temp_sum)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                accel_x <= (others => '0');
                accel_y <= (others => '0');
                accel_z <= (others => '0');
                accel_temp <= (others => '0');
            elsif delaying_data_ready = '1' then
                accel_x <= accel_x_sum ((11 + (extra_bits)) downto (extra_bits));
                accel_y <= accel_y_sum ((11 + (extra_bits)) downto (extra_bits));
                accel_z <= accel_z_sum ((11 + (extra_bits)) downto (extra_bits));
                accel_temp <= accel_temp_sum ((11 + (extra_bits)) downto (extra_bits));
            end if;
        end if;
    end process;

    process (clk108mhz, reset, delaying_data_ready)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                accel_ready <= '0';
            else
                accel_ready <= delaying_data_ready; -- For stable output
            end if;
        end if;
    end process;

end Behavioral;
