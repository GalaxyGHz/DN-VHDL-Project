----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_signed.all;

entity accelerometer is
    port (
        clk108mhz  : in STD_LOGIC; -- System Clock
        reset      : in STD_LOGIC;
        -- Accelerometer data signals
        accel_x    : out STD_LOGIC_VECTOR (9 downto 0);
        accel_y    : out STD_LOGIC_VECTOR (9 downto 0);
        accel_ready : out STD_LOGIC;
        --SPI Interface Signals
        sclk       : out STD_LOGIC;
        mosi       : out STD_LOGIC;
        miso       : in STD_LOGIC;
        ss         : out STD_LOGIC
    );
end accelerometer;

architecture Behavioral of accelerometer is

    signal accel_x_in    :  STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    signal accel_y_in    :  STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    signal accel_ready_in    :  STD_LOGIC := '0';
    -- Not used --------------------------------------------------------------
    signal accel_z_in    :  STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    signal accel_temp_in :  STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    --------------------------------------------------------------------------

    -- The accelerometer currently returns value from -2047 to 2048, we will add 2047 to
    -- translate the returned values for easier manipulation (to 0 to 4095)
    constant transform : std_logic_vector (12 downto 0) :=  '0' & X"7FF"; --2047

    -- Invert X axis data in order to display it on the screen correctly
    signal accel_x_in_inv : STD_LOGIC_VECTOR (11 downto 0) := (others => '0');

    signal accel_x_shifted : std_logic_vector (12 downto 0) := (others => '0'); -- one more bit to keep the sign extension
    signal accel_y_shifted : std_logic_vector (12 downto 0) := (others => '0');

begin

    accel_x_in_inv <= -accel_x_in;

    -- Transform to 0 to 4095
    process (clk108mhz, reset, accel_x_in, accel_y_in, accel_ready_in)
    begin
        if rising_edge(clk108mhz) then
            if reset = '1' then
                accel_x_shifted <= (others => '0');
                accel_y_shifted <= (others => '0');
            elsif accel_ready_in = '1' then
                if accel_y_in(11) = '1' then -- if negative, keep the sign extension
                    accel_y_shifted <= ('1' & accel_y_in) + transform;
                else
                    accel_y_shifted <= ('0' & accel_y_in) + transform;
                end if;

                if accel_x_in_inv(11) = '1' then -- if negative, keep the sign extension
                    accel_x_shifted <= ('1' & accel_x_in_inv) + transform;
                else
                    accel_x_shifted <= ('0' & accel_x_in_inv) + transform;

                end if;
            end if;
        end if;
    end process;

    -- Divide by 4 to get values from 0 to 1024, since our screen has resolution 1280x1024, there 
    -- is no need for higher values
    accel_x <= accel_x_shifted(11 downto 2);
    accel_y <= accel_y_shifted(11 downto 2);
    accel_ready <= accel_ready_in;

    adxl: entity work.ADXL362Ctrl(Behavioral)
        port map (
            SYSCLK => clk108mhz,
            reset => reset,
            -- Accelerometer data signals
            ACCEL_X => accel_x_in,
            ACCEL_Y => accel_y_in,
            ACCEL_Z => accel_z_in,
            ACCEL_TMP => accel_temp_in,
            Data_Ready => accel_ready_in,
            --SPI Interface Signals
            sclk => sclk,
            mosi => mosi,
            miso => miso,
            ss => ss
        );

end Behavioral;
