library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.arraypkg.all;  -- vec64_array, vec8_array

entity prefixaccumulatoroptimized is
  port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    start       : in  std_logic;
    values      : in  vec64_array(0 to 149);  
    indices     : in  vec8_array(0 to 149);   
    threshold   : in  std_logic_vector(15 downto 0);  
    totalsum    : out std_logic_vector(63 downto 0);
    crossed     : out std_logic;                    -- ThresholdMet
    indexout    : out std_logic_vector(7 downto 0);
    debug_index : out std_logic_vector(3 downto 0);
    countdone   : out std_logic                     
  );
end prefixaccumulatoroptimized;

architecture behavioral of prefixaccumulatoroptimized is
  constant BLOCK_SIZE : integer := 5;
  constant NUM_BLOCKS : integer := 150 / BLOCK_SIZE;

  type blocksumarray  is array(0 to BLOCK_SIZE-1) of unsigned(63 downto 0);
  type blocksumarrays is array(0 to NUM_BLOCKS-1) of blocksumarray;
  type totalarray     is array(0 to NUM_BLOCKS-1) of unsigned(63 downto 0);

  signal regTotalSum   : unsigned(63 downto 0) := (others=>'0');
  signal regCrossed    : std_logic := '0';
  signal regIndexOut   : unsigned(7 downto 0) := (others=>'0');
  signal regDebugIndex : unsigned(3 downto 0) := (others=>'0');
  signal regCountDone  : std_logic := '0';
begin

  process(clk, reset)
    variable thresh64    : unsigned(63 downto 0);
    variable localsums   : blocksumarrays;
    variable blocktotal  : totalarray;
    variable cumsum      : totalarray;
    variable foundindex  : integer := -1;
    variable total       : unsigned(63 downto 0);
    variable offset_val  : unsigned(63 downto 0);
    variable selblock    : integer := -1;
  begin
    if reset='1' then
      regTotalSum   <= (others=>'0');
      regCrossed    <= '0';
      regIndexOut   <= (others=>'0');
      regDebugIndex <= (others=>'0');
      regCountDone  <= '0';
      foundindex    := -1;

    elsif rising_edge(clk) then
      if start='1' then
        -- extend threshold
        thresh64 := (others=>'0');
        thresh64(15 downto 0) := unsigned(threshold);

        -- local prefix sums & block totals
        for b in 0 to NUM_BLOCKS-1 loop
          localsums(b)(0) := unsigned(values(b*BLOCK_SIZE));
          for j in 1 to BLOCK_SIZE-1 loop
            localsums(b)(j) := localsums(b)(j-1) + unsigned(values(b*BLOCK_SIZE+j));
          end loop;
          blocktotal(b) := localsums(b)(BLOCK_SIZE-1);
        end loop;

        -- cumulative sums
        cumsum(0) := blocktotal(0);
        for b in 1 to NUM_BLOCKS-1 loop
          cumsum(b) := cumsum(b-1) + blocktotal(b);
        end loop;
        total := cumsum(NUM_BLOCKS-1);

        -- find block crossing
        selblock := -1;
        for b in 0 to NUM_BLOCKS-1 loop
          if cumsum(b) >= thresh64 then
            selblock := b;
            exit;
          end if;
        end loop;

        -- find exact index inside that block
        if selblock /= -1 then
          if selblock=0 then
            offset_val := (others=>'0');
          else
            offset_val := cumsum(selblock-1);
          end if;
          for j in 0 to BLOCK_SIZE-1 loop
            if (offset_val + localsums(selblock)(j)) >= thresh64 then
              foundindex := selblock*BLOCK_SIZE + j;
              exit;
            end if;
          end loop;
          regCrossed    <= '1';
          regIndexOut   <= unsigned(indices(foundindex));
          regDebugIndex <= to_unsigned(foundindex,4);

        else
          -- no crossing return –1
          regCrossed    <= '0';
          regIndexOut   <= (others=>'1');  -- 0xFF = –1 in 8‑bit
          regDebugIndex <= (others=>'1');  
        end if;

        regTotalSum  <= total;
        regCountDone <= '1';  -- one‑cycle flag

      else
        regCountDone <= '0';
      end if;
    end if;
  end process;

  totalsum  <= std_logic_vector(regTotalSum);
  crossed   <= regCrossed;
  indexout  <= std_logic_vector(regIndexOut);
  debug_index <= std_logic_vector(regDebugIndex);
  countdone <= regCountDone;
end behavioral;
