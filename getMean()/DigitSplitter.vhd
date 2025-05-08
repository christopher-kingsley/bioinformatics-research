library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DigitSplitter is
    port (
        value     : in  std_logic_vector(63 downto 0);
        hundreds  : out std_logic_vector(3 downto 0);
        tens      : out std_logic_vector(3 downto 0);
        ones      : out std_logic_vector(3 downto 0)
    );
end entity;

architecture Behavioral of DigitSplitter is
    signal decimal : integer := 0;
begin
    process(value)
    begin
        decimal <= to_integer(unsigned(value)) mod 1000;
        hundreds <= std_logic_vector(to_unsigned((decimal / 100) mod 10, 4));
        tens     <= std_logic_vector(to_unsigned((decimal / 10) mod 10, 4));
        ones     <= std_logic_vector(to_unsigned(decimal mod 10, 4));
    end process;
end architecture;

