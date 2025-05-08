library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Use numeric_std for arithmetic operations

entity getPercentileMultiplier is
    Port (
        Clk       : in std_logic;  -- Clock for synchronization
        StartMult : in std_logic;  
        A         : in std_logic_vector(15 downto 0);  -- totalCounts
        B         : in std_logic_vector(15 downto 0);  -- percentile
        Product   : out std_logic_vector(31 downto 0); -- 
        MultDone  : out std_logic -- 
    );
end entity;

architecture beh of getPercentileMultiplier is
    signal product_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal done_signal : std_logic := '0';
begin
    process (Clk)
    begin
        if rising_edge(Clk) then
            if StartMult = '1' then
                product_reg <= std_logic_vector(unsigned(A) * unsigned(B));
                done_signal <= '1';   
            else
                done_signal <= '0';   -- Reset done signal when not active
            end if;
        end if;
    end process;

    Product  <= product_reg;
    MultDone <= done_signal;

end beh;