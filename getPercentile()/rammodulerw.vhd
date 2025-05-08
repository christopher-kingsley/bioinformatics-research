library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.arraypkg.all;  -- this package defines vec64_array and vec8_array

-- RAMModuleRW: 150‑deep RAM with read/write, offset masking, 
-- and correct index output (address as index).
entity rammodulerw is
  port(
    clk          : in  std_logic;
    enable       : in  std_logic;                   -- active‑high read enable
    offset       : in  std_logic_vector(7 downto 0);-- addresses below this are forced to 0
    write_enable : in  std_logic;                   -- when high, performs a write
    write_addr   : in  integer range 0 to 149;      -- write address
    write_data   : in  std_logic_vector(63 downto 0); -- data to write
    values_out   : out vec64_array(0 to 149);       -- output values (with offset)
    indices_out  : out vec8_array(0 to 149)         -- output indices (= address)
  );
end rammodulerw;

architecture behavioral of rammodulerw is

  -- Internal type for storing 150 × 64‑bit words
  type ram64_type is array (0 to 149) of std_logic_vector(63 downto 0);

  -- Preload every address so total sum = 159 (addr0 = 10, others = 1)
  constant default_values : ram64_type := (
    0      => x"000000000000000A",
    others => x"0000000000000001"
  );

  -- Memory signal for values
  signal mem_values : ram64_type := default_values;

  -- Signals to hold our cycle‑by‑cycle outputs
  signal out_values_signal  : vec64_array(0 to 149);
  signal out_indices_signal : vec8_array(0 to 149);

begin

  process(clk)
    -- Temporary arrays for constructing outputs each clock
    variable tmp_vals : vec64_array(0 to 149);
    variable tmp_idx  : vec8_array (0 to 149);
    variable offs_int : integer := 0;
  begin
    if rising_edge(clk) then
      -- Convert the 8‑bit offset vector to an integer
      offs_int := to_integer(unsigned(offset));

      -- Handle writes
      if write_enable = '1' then
        mem_values(write_addr) <= write_data;
      end if;

      -- Always‑on read path (masked by enable + offset)
      if enable = '1' then
        for i in 0 to 149 loop
          if i < offs_int then
            -- Mask out lower addresses
            tmp_vals(i) := (others => '0');
            tmp_idx (i) := (others => '0');
          else
            -- Pass stored value and use the address as the index
            tmp_vals(i) := mem_values(i);
            tmp_idx (i) := std_logic_vector(to_unsigned(i, 8));
          end if;
        end loop;
        out_values_signal  <= tmp_vals;
        out_indices_signal <= tmp_idx;
      else
        -- If disabled, drive all zeros
        out_values_signal  <= (others => (others => '0'));
        out_indices_signal <= (others => (others => '0'));
      end if;
    end if;
  end process;

  -- Hook up to the entity outputs
  values_out  <= out_values_signal;
  indices_out <= out_indices_signal;

end behavioral;
