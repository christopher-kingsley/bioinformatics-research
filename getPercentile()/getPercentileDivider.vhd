library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity getPercentileDivider is 
    port(
        clk        : in std_logic;
        StartDiv   : in std_logic; 
        total      : in std_logic_vector(31 downto 0); -- Dividend
        totalOut   : out std_logic_vector(31 downto 0); -- Quotient
        DivDone    : out std_logic 
    );
end entity;

architecture beh of getPercentileDivider is
    signal totalOutSignal : unsigned(31 downto 0) := (others => '0');
    signal done_signal : std_logic := '0';
    constant DIVISOR : unsigned(31 downto 0) := to_unsigned(100, 32); -- 100

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if StartDiv = '1' then
                totalOutSignal <= unsigned(total) / DIVISOR; 
                done_signal <= '1'; 
            end if;
        end if;
    end process;

    -- Assign outputs
    totalOut <= std_logic_vector(totalOutSignal);
    DivDone  <= done_signal;

end beh;
