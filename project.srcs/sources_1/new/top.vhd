------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        CLK100MHZ          : in  std_logic;
        CPU_RESETN         : in  std_logic;
        -- VGA connections
        VGA_HS       : out std_logic;
        VGA_VS       : out std_logic;
        VGA_R      : out std_logic_vector(3 downto 0);
        VGA_G    : out std_logic_vector(3 downto 0);
        VGA_B     : out std_logic_vector(3 downto 0);
        -- SPI connections for accelerometer
        ACL_MISO : in std_logic;
        ACL_MOSI : out std_logic;
        ACL_SCLK : out std_logic;
        ACL_SS : out std_logic
    );
end top;

architecture Behavioral of top is

    -- Clock used for vga 1280x1024
    signal CLK108MHZ : std_logic;

    -- VGA pixel information
    signal DISPLAY_AREA : std_logic;
    signal COLUMN : natural range 0 to 1279;
    signal ROW : natural range 0 to 1023;

    -- Accelerometer information
    signal ACCEL_X : STD_LOGIC_VECTOR (9 downto 0);
    signal ACCEL_Y: STD_LOGIC_VECTOR (9 downto 0);
    signal ACCEL_READY : std_logic;

    -- Spaceship position
    signal SPACESHIP_POS_X : natural range 0 to 1279;
    signal SPACESHIP_POS_Y : natural range 0 to 1023;

begin

    -- Clock generator (108MHZ)
    clk108: entity work.ClkGen(Behavioral)
        port map (
            clk100mhz => CLK100MHZ,
            clk108mhz => CLK108MHZ
        );

    -- VGA controller
    VGA: entity work.VGA(Behavioral)
        port map (
            clk108mhz => CLK108MHZ,
            reset => not CPU_RESETN,
            vga_hs => VGA_HS,
            vga_vs => VGA_VS,
            column => COLUMN,
            row => ROW,
            display_area => DISPLAY_AREA
        );

    -- Accelerometer controller
    accelerometer: entity work.accelerometer(Behavioral)
        port map (
            clk108mhz => CLK108MHZ,
            reset => not CPU_RESETN,
            -- Accelerometer data signals
            accel_x => ACCEL_X,
            accel_y => ACCEL_Y,
            accel_ready => ACCEL_READY,
            --SPI Interface Signals
            sclk => ACL_SCLK,
            mosi => ACL_MOSI,
            miso => ACL_MISO,
            ss => ACL_SS
        );
    
    -- Spaceship position calculator
    spaceship: entity work.spaceship(Behavioral)
        port map (
            clk108mhz => CLK108MHZ,
            reset => not CPU_RESETN,
            accel_x => ACCEL_X,
            accel_y => ACCEL_Y,
            accel_ready => ACCEL_READY,
            spaceship_pos_x => SPACESHIP_POS_X,
            spaceship_pos_y => SPACESHIP_POS_Y
        );
      
    -- Drawing logic
    drawer: entity work.drawer(Behavioral)
        port map (
        clock => CLK108MHZ,
           display_area => DISPLAY_AREA,
           column => COLUMN, 
           row => ROW,
           spaceship_pos_x => SPACESHIP_POS_X,
           spaceship_pos_y => SPACESHIP_POS_Y,
           vga_r => VGA_R,
           vga_g => VGA_G,
           vga_b => VGA_B
        );

end Behavioral;