library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity VGA is
    Port ( clk108mhz : in STD_LOGIC;
         reset : in STD_LOGIC;
         vga_hs : out STD_LOGIC;
         vga_vs : out STD_LOGIC;
         column : out natural range 0 to 1279;
         row : out natural range 0 to 1023;
         display_area : out std_logic
        );
end VGA;

architecture Behavioral of VGA is

    signal clock_enable : std_logic;
    
    signal display_area_h : std_logic;
    signal display_area_v : std_logic;

begin
    -- Povezovanje komponent: modula hsync in vsync
    hsync: entity work.hsync
        port map(
            clock => clk108mhz,
            reset => reset,
            clock_enable => clock_enable,
            display_area => display_area_h,
            column => column,
            hsync => vga_hs
        );

    vsync: entity work.vsync
        port map(
            clock => clk108mhz,
            reset => reset,
            clock_enable => clock_enable,
            display_area => display_area_v,
            row => row,
            vsync => vga_vs
        );

    -- Logika za prižig elektronskih topov (signali RGB)
    display_area <= display_area_h AND display_area_v;

end Behavioral;
