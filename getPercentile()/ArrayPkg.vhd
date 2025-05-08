library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ArrayPkg is
    type vec64_array is array (natural range <>) of std_logic_vector(63 downto 0);
    type vec8_array  is array (natural range <>) of std_logic_vector(7 downto 0);
end package ArrayPkg;
