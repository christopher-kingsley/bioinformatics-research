library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.arraypkg.all;    

entity MeanAccumulatorTree is
  generic ( N : integer := 150 );
  port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    start       : in  std_logic;                    
    weighted_in : in  vec64_array(0 to N-1);          -- counts*(i-offset)
    counts_in   : in  vec64_array(0 to N-1);          -- raw counts masked
    sum_out     : out std_logic_vector(63 downto 0);  
    count_out   : out std_logic_vector(63 downto 0);  
    done        : out std_logic                       
  );
end entity;

architecture Tree of MeanAccumulatorTree is
  constant STAGES : integer := 8;

  type uw64_t      is array(0 to N-1) of unsigned(63 downto 0);
  type stage_arr_t is array(0 to STAGES) of uw64_t;

  signal leaf_sum, leaf_cnt : uw64_t;
  signal tree_sum, tree_cnt : stage_arr_t;
  signal valid_pipe         : std_logic_vector(0 to STAGES);
begin

  -- 1) Leaf capture
  gen_leaf: for i in 0 to N-1 generate
  begin
    leaf_sum(i) <= unsigned(weighted_in(i));
    leaf_cnt(i) <= unsigned(counts_in(i));
  end generate;

  -- 2) Reduction tree
  gen_reduce: for lvl in 1 to STAGES generate
    constant prev_sz : integer := (N + 2**(lvl-1) - 1) / 2**(lvl-1);
    constant curr_sz : integer := (prev_sz + 1) / 2;
  begin
    gen_pair: for j in 0 to curr_sz-1 generate
      signal lhs_sum, rhs_sum : unsigned(63 downto 0);
      signal lhs_cnt, rhs_cnt : unsigned(63 downto 0);
    begin
      -- left operand
      lhs_sum <= leaf_sum(2*j) when lvl = 1 else tree_sum(lvl-1)(2*j);
      lhs_cnt <= leaf_cnt(2*j) when lvl = 1 else tree_cnt(lvl-1)(2*j);

      -- right operand, zero if out of range
      rhs_sum <= leaf_sum(2*j+1)
                  when (lvl = 1 and 2*j+1 < prev_sz) else
                tree_sum(lvl-1)(2*j+1)
                  when (lvl > 1 and 2*j+1 < prev_sz) else
                (others => '0');

      rhs_cnt <= leaf_cnt(2*j+1)
                  when (lvl = 1 and 2*j+1 < prev_sz) else
                tree_cnt(lvl-1)(2*j+1)
                  when (lvl > 1 and 2*j+1 < prev_sz) else
                (others => '0');

      -- sum
      tree_sum(lvl)(j) <= lhs_sum + rhs_sum;
      tree_cnt(lvl)(j) <= lhs_cnt + rhs_cnt;
    end generate;
  end generate;

  -- 3) Valid pulse pipeline
  process(clk, reset)
  begin
    if reset = '1' then
      valid_pipe <= (others => '0');
    elsif rising_edge(clk) then
      valid_pipe(0) <= start;
      for k in 1 to STAGES loop
        valid_pipe(k) <= valid_pipe(k-1);
      end loop;
    end if;
  end process;

  -- 4) Latch outputs when done
  process(clk, reset)
  begin
    if reset = '1' then
      sum_out   <= (others => '0');
      count_out <= (others => '0');
      done      <= '0';
    elsif rising_edge(clk) then
      if valid_pipe(STAGES) = '1' then
        sum_out   <= std_logic_vector(tree_sum(STAGES)(0));
        count_out <= std_logic_vector(tree_cnt (STAGES)(0));
        done      <= '1';
      else
        done <= '0';
      end if;
    end if;
  end process;

end architecture Tree;

