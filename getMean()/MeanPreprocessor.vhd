library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.arraypkg.all;  

entity MeanPreprocessor is
  generic (
    N : integer := 150
  );
  port(
    offset       : in  std_logic_vector(7 downto 0);
    values_in    : in  vec64_array(0 to N-1);
    weighted_out : out vec64_array(0 to N-1);
    counts_out   : out vec64_array(0 to N-1)
  );
end entity;

architecture Comb of MeanPreprocessor is
begin

  gen_pp: for i in 0 to N-1 generate
    constant idx_u : unsigned(7 downto 0) := to_unsigned(i, 8);
    signal diff64  : unsigned(63 downto 0);
  begin
    -- compute (i - offset) as 64-bit, or zero if i<offset
	 
    diff64 <= resize(idx_u - unsigned(offset), 64)
              when idx_u >= unsigned(offset)
              else (others => '0');
				  

    weighted_out(i) <= std_logic_vector(
                         resize(unsigned(values_in(i)) * diff64, 64)
                       ) when idx_u >= unsigned(offset)
                         else (others => '0');


    counts_out(i) <= values_in(i)
                       when idx_u >= unsigned(offset)
                       else (others => '0');
  end generate gen_pp;

end architecture Comb;
