library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MeanDivider is
  port(
    clk      : in  std_logic;
    reset    : in  std_logic;
    start    : in  std_logic;
    dividend : in  std_logic_vector(63 downto 0);
    divisor  : in  std_logic_vector(63 downto 0);
    quotient : out std_logic_vector(63 downto 0);
    done     : out std_logic
  );
end MeanDivider;

architecture Behavioral of MeanDivider is
begin
  process(clk, reset)
  begin
    if reset = '1' then
      quotient <= (others => '0');
      done     <= '0';

    elsif rising_edge(clk) then
      if start = '1' then
        -- use numeric_std division
        quotient <= std_logic_vector(
                      unsigned(dividend) / unsigned(divisor)
                    );
        done <= '1';
      else
        done <= '0';
      end if;
    end if;
  end process;
end Behavioral;

