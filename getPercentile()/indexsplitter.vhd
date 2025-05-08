library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity indexsplitter is
    port(
        value : in  std_logic_vector(7 downto 0);
        tens  : out std_logic_vector(3 downto 0);
        ones  : out std_logic_vector(3 downto 0)
    );
end entity;

architecture behavioral of indexsplitter is
begin
    process(value)
        variable int_value : integer; 
    begin
        if value = x"FF" then
            -- blank display on –1
            tens <= "1111";
            ones <= "1111";
        else
            int_value := to_integer(unsigned(value));
            tens      <= std_logic_vector( to_unsigned((int_value / 10) mod 10, 4) );
            ones      <= std_logic_vector( to_unsigned( int_value mod 10,      4) );
        end if;
    end process;
end architecture;
