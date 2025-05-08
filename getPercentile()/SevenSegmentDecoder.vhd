library ieee;
use ieee.std_logic_1164.all;

entity SevenSegmentDecoder is
    port (
        digit     : in  std_logic_vector(3 downto 0);
        segments  : out std_logic_vector(6 downto 0)  -- a to g
    );
end entity;

architecture behavioral of SevenSegmentDecoder is
begin
    process(digit)
    begin
        case digit is
            when "0000" => segments <= "1000000"; -- 0
            when "0001" => segments <= "1111001"; -- 1
            when "0010" => segments <= "0100100"; -- 2
            when "0011" => segments <= "0110000"; -- 3
            when "0100" => segments <= "0011001"; -- 4
            when "0101" => segments <= "0010010"; -- 5
            when "0110" => segments <= "0000010"; -- 6
            when "0111" => segments <= "1111000"; -- 7
            when "1000" => segments <= "0000000"; -- 8
            when "1001" => segments <= "0010000"; -- 9
            when others => segments <= "1111111"; -- blank
        end case;
    end process;
end architecture;
