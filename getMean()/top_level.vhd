library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.arraypkg.all;  

entity top_level is
  port(
    clk                : in  std_logic;
    reset              : in  std_logic;
    start              : in  std_logic;                         -- finger‐flip to begin
    write_req          : in  std_logic;                         -- high while writing RAM
    offset             : in  std_logic_vector(7 downto 0);   
    write_addr         : in  integer range 0 to 149;          
    write_data         : in  std_logic_vector(63 downto 0);   

    -- mean result display
    seg_mean_hundreds  : out std_logic_vector(6 downto 0);
    seg_mean_tens      : out std_logic_vector(6 downto 0);
    seg_mean_units     : out std_logic_vector(6 downto 0);

    -- cycle count display
    seg_count_hundreds : out std_logic_vector(6 downto 0);
    seg_count_tens     : out std_logic_vector(6 downto 0);
    seg_count_units    : out std_logic_vector(6 downto 0)
  );
end entity;

architecture RTL of top_level is


  component ControlFSM
    port(
      clk        : in  std_logic;
      reset      : in  std_logic;
      start      : in  std_logic;
      write_req  : in  std_logic;
      acc_done   : in  std_logic;
      div_done   : in  std_logic;
      ram_we     : out std_logic;
      start_acc  : out std_logic;
      start_div  : out std_logic;
      result_out : out std_logic;
      busy       : out std_logic
    );
  end component;

  component rammodulerw
    port(
      clk          : in  std_logic;
      enable       : in  std_logic;
      offset       : in  std_logic_vector(7 downto 0);
      write_enable : in  std_logic;
      write_addr   : in  integer range 0 to 149;
      write_data   : in  std_logic_vector(63 downto 0);
      values_out   : out vec64_array(0 to 149);
      indices_out  : out vec8_array(0 to 149)
    );
  end component;

  component MeanPreprocessor
    generic (N : integer := 150);
    port(
      offset       : in  std_logic_vector(7 downto 0);
      values_in    : in  vec64_array(0 to N-1);
      weighted_out : out vec64_array(0 to N-1);
      counts_out   : out vec64_array(0 to N-1)
    );
  end component;

  component MeanAccumulatorTree
    generic (N : integer := 150);
    port(
      clk         : in  std_logic;
      reset       : in  std_logic;
      start       : in  std_logic;
      weighted_in : in  vec64_array(0 to N-1);
      counts_in   : in  vec64_array(0 to N-1);
      sum_out     : out std_logic_vector(63 downto 0);
      count_out   : out std_logic_vector(63 downto 0);
      done        : out std_logic
    );
  end component;

  component MeanDivider
    port(
      clk      : in  std_logic;
      reset    : in  std_logic;
      start    : in  std_logic;
      dividend : in  std_logic_vector(63 downto 0);
      divisor  : in  std_logic_vector(63 downto 0);
      quotient : out std_logic_vector(63 downto 0);
      done     : out std_logic
    );
  end component;

  component DigitSplitter
    port(
      value    : in  std_logic_vector(63 downto 0);
      hundreds : out std_logic_vector(3 downto 0);
      tens     : out std_logic_vector(3 downto 0);
      ones     : out std_logic_vector(3 downto 0)
    );
  end component;

  component SevenSegmentDecoder
    port(
      digit    : in  std_logic_vector(3 downto 0);
      segments : out std_logic_vector(6 downto 0)
    );
  end component;

  -- Internal signals
  signal ram_we        : std_logic;
  signal start_acc     : std_logic;
  signal start_div     : std_logic;
  signal acc_done      : std_logic;
  signal div_done      : std_logic;
  signal result_out    : std_logic;

  signal layer_vals    : vec64_array(0 to 149);
  signal layer_idxs    : vec8_array(0 to 149);

  signal weighted_vals : vec64_array(0 to 149);
  signal masked_counts : vec64_array(0 to 149);

  signal mean_sum      : std_logic_vector(63 downto 0);
  signal mean_count    : std_logic_vector(63 downto 0);
  signal quotient      : std_logic_vector(63 downto 0);

  -- cycle counter signals
  signal start_d             : std_logic := '0';
  signal counter_running     : std_logic := '0';
  signal cycle_counter       : unsigned(63 downto 0) := (others => '0');
  signal cycle_count_latched : std_logic_vector(63 downto 0) := (others => '0');

  -- display digit splits
  signal mean_h, mean_t, mean_u : std_logic_vector(3 downto 0);
  signal cnt_h, cnt_t, cnt_u    : std_logic_vector(3 downto 0);

begin

  UCFSM: ControlFSM
    port map(
      clk        => clk,
      reset      => reset,
      start      => start,
      write_req  => write_req,
      acc_done   => acc_done,
      div_done   => div_done,
      ram_we     => ram_we,
      start_acc  => start_acc,
      start_div  => start_div,
      result_out => result_out,
      busy       => open
    );

  URAM: rammodulerw
    port map(
      clk          => clk,
      enable       => '1',
      offset       => offset,
      write_enable => ram_we,
      write_addr   => write_addr,
      write_data   => write_data,
      values_out   => layer_vals,
      indices_out  => layer_idxs
    );

  UPP: MeanPreprocessor
    generic map(N => 150)
    port map(
      offset       => offset,
      values_in    => layer_vals,
      weighted_out => weighted_vals,
      counts_out   => masked_counts
    );


  UACC: MeanAccumulatorTree
    generic map(N => 150)
    port map(
      clk         => clk,
      reset       => reset,
      start       => start_acc,
      weighted_in => weighted_vals,
      counts_in   => masked_counts,
      sum_out     => mean_sum,
      count_out   => mean_count,
      done        => acc_done
    );


  UDIV: MeanDivider
    port map(
      clk      => clk,
      reset    => reset,
      start    => acc_done,
      dividend => mean_sum,
      divisor  => mean_count,
      quotient => quotient,
      done     => div_done
    );


  process(clk, reset)
  begin
    if reset = '1' then
      start_d             <= '0';
      counter_running     <= '0';
      cycle_counter       <= (others => '0');
      cycle_count_latched <= (others => '0');

    elsif rising_edge(clk) then
      -- detect start rising edge
      start_d <= start;
      if (start = '1' and start_d = '0') then
        counter_running <= '1';
        cycle_counter   <= (others => '0');

      elsif counter_running = '1' then
        if result_out = '1' then
          counter_running     <= '0';
          cycle_count_latched <= std_logic_vector(cycle_counter);
        else
          cycle_counter <= cycle_counter + 1;
        end if;
      end if;
    end if;
  end process;


  DS_MEAN: DigitSplitter
    port map(value => quotient, hundreds => mean_h, tens => mean_t, ones => mean_u);
  SSD_MEAN_H: SevenSegmentDecoder port map(digit => mean_h, segments => seg_mean_hundreds);
  SSD_MEAN_T: SevenSegmentDecoder port map(digit => mean_t, segments => seg_mean_tens);
  SSD_MEAN_U: SevenSegmentDecoder port map(digit => mean_u, segments => seg_mean_units);

  -- Display cycle count
  DS_CNT: DigitSplitter
    port map(value => cycle_count_latched, hundreds => cnt_h, tens => cnt_t, ones => cnt_u);
  SSD_CNT_H: SevenSegmentDecoder port map(digit => cnt_h, segments => seg_count_hundreds);
  SSD_CNT_T: SevenSegmentDecoder port map(digit => cnt_t, segments => seg_count_tens);
  SSD_CNT_U: SevenSegmentDecoder port map(digit => cnt_u, segments => seg_count_units);

end architecture RTL;
