library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.arraypkg.all;  -- defines vec64_array and vec8_array

entity top_level is
  port(
    clk               : in  std_logic;                        -- system clock
    reset             : in  std_logic;
    start             : in  std_logic;                        -- pulse to kick FSM
    offset            : in  std_logic_vector(7 downto 0);     -- mask offset

    led_heartbeat     : out std_logic;                        -- heartbeat LED

    -- display for cycle count
    seg_hundreds      : out std_logic_vector(6 downto 0);
    seg_tens          : out std_logic_vector(6 downto 0);
    seg_units         : out std_logic_vector(6 downto 0);

    -- display for result index
    seg_index_tens    : out std_logic_vector(6 downto 0);
    seg_index_units   : out std_logic_vector(6 downto 0);

    -- status LEDs
    threshold_crossed : out std_logic;
    debug_crossed     : out std_logic;
    debug_sum_exceeded: out std_logic;
    debug_condition   : out std_logic_vector(2 downto 0);     -- full FSM state

    -- raw index out (-1 = x"FF")
    index_out         : out std_logic_vector(7 downto 0)
  );
end entity;

architecture behavioral of top_level is

  -- FSM
  component getPercentileFSM is
    port(
      Clk, Reset, Enable      : in  std_logic;
      MultDone, DivDone       : in  std_logic;
      ThresholdMet, CountDone : in  std_logic;
      StartMult, StartDiv     : out std_logic;
      EnableCount, StartAcc   : out std_logic;
      Done                     : out std_logic;
      FSM_State                : out std_logic_vector(2 downto 0)
    );
  end component;

  component getPercentileMultiplier is
    port(
      Clk       : in  std_logic;
      StartMult : in  std_logic;
      A         : in  std_logic_vector(15 downto 0);
      B         : in  std_logic_vector(15 downto 0);
      Product   : out std_logic_vector(31 downto 0);
      MultDone  : out std_logic
    );
  end component;

  component getPercentileDivider is 
    port(
      clk      : in  std_logic;
      StartDiv : in  std_logic;
      total    : in  std_logic_vector(31 downto 0);
      totalOut : out std_logic_vector(31 downto 0);
      DivDone  : out std_logic
    );
  end component;

  component RAMModuleRW is
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

  component PrefixAccumulatorOptimized is
    port(
      clk         : in  std_logic;
      reset       : in  std_logic;
      start       : in  std_logic;
      values      : in  vec64_array(0 to 149);
      indices     : in  vec8_array(0 to 149);
      threshold   : in  std_logic_vector(15 downto 0);
      totalsum    : out std_logic_vector(63 downto 0);
      crossed     : out std_logic;
      indexout    : out std_logic_vector(7 downto 0);
      countdone   : out std_logic
    );
  end component;

  component DigitSplitter is
    port(
      value    : in  std_logic_vector(63 downto 0);
      hundreds : out std_logic_vector(3 downto 0);
      tens     : out std_logic_vector(3 downto 0);
      ones     : out std_logic_vector(3 downto 0)
    );
  end component;

  component indexsplitter is
    port(
      value : in  std_logic_vector(7 downto 0);
      tens  : out std_logic_vector(3 downto 0);
      ones  : out std_logic_vector(3 downto 0)
    );
  end component;

  component SevenSegmentDecoder is
    port(
      digit    : in  std_logic_vector(3 downto 0);
      segments : out std_logic_vector(6 downto 0)
    );
  end component;

  -- Signals
  signal mult_product      : std_logic_vector(31 downto 0);
  signal threshold32       : std_logic_vector(31 downto 0);
  signal threshold16       : std_logic_vector(15 downto 0);
  signal multdone, divdone : std_logic;
  signal start_mult, start_div   : std_logic;
  signal enable_count, start_acc : std_logic;
  signal done_fsm                : std_logic;
  signal fsm_state               : std_logic_vector(2 downto 0);

  signal layer_vals    : vec64_array(0 to 149);
  signal layer_idxs    : vec8_array(0 to 149);
  signal raw_crossed   : std_logic;
  signal raw_index     : std_logic_vector(7 downto 0);
  signal raw_done      : std_logic;

  signal adjusted_index : std_logic_vector(7 downto 0);

  -- Cycle counter signals (64-bit)
  signal start_d             : std_logic := '0';
  signal counter_running     : std_logic := '0';
  signal cycle_counter       : unsigned(63 downto 0) := (others => '0');
  signal cycle_count_latched : std_logic_vector(63 downto 0) := (others => '0');

  -- display digits
  signal cnt_h, cnt_t, cnt_u : std_logic_vector(3 downto 0);
  signal idx_h, idx_l        : std_logic_vector(3 downto 0);

  -- Constants
  constant TOTALCOUNTS_CONST : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(159,16));
  constant PERCENTILE_CONST  : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(75,16));

begin


  -- FSM
  UGFSM: getPercentileFSM
    port map(
      Clk          => clk,
      Reset        => reset,
      Enable       => start,
      MultDone     => multdone,
      DivDone      => divdone,
      ThresholdMet => raw_crossed,
      CountDone    => raw_done,
      StartMult    => start_mult,
      StartDiv     => start_div,
      EnableCount  => enable_count,
      StartAcc     => start_acc,
      Done         => done_fsm,
      FSM_State    => fsm_state
    );

  -- Multiplier
  UGMUL: getPercentileMultiplier
    port map(
      Clk       => clk,
      StartMult => start_mult,
      A         => TOTALCOUNTS_CONST,
      B         => PERCENTILE_CONST,
      Product   => mult_product,
      MultDone  => multdone
    );

  -- Divider
  UGDIV2: getPercentileDivider
    port map(
      clk      => clk,
      StartDiv => start_div,
      total    => mult_product,
      totalOut => threshold32,
      DivDone  => divdone
    );
  threshold16 <= threshold32(15 downto 0);

  -- RAM
  URAM: RAMModuleRW
    port map(
      clk          => clk,
      enable       => '1',
      offset       => offset,
      write_enable => '0',
      write_addr   => 0,
      write_data   => (others=>'0'),
      values_out   => layer_vals,
      indices_out  => layer_idxs
    );

  -- Accumulator
  UPREFIX: PrefixAccumulatorOptimized
    port map(
      clk         => clk,
      reset       => reset,
      start       => start_acc,
      values      => layer_vals,
      indices     => layer_idxs,
      threshold   => threshold16,
      totalsum    => open,
      crossed     => raw_crossed,
      indexout    => raw_index,
      countdone   => raw_done
    );

  -- Adjusted index
  adjusted_index <= std_logic_vector(
                       unsigned(raw_index) - unsigned(offset)
                     ) when raw_crossed='1'
                     else (others=>'1');
  index_out <= adjusted_index;

  -- Status LEDs
  threshold_crossed  <= raw_crossed;
  debug_crossed      <= raw_crossed;
  debug_sum_exceeded <= '0';
  debug_condition    <= fsm_state;


  process(clk, reset)
  begin
    if reset='1' then
      start_d             <= '0';
      counter_running     <= '0';
      cycle_counter       <= (others=>'0');
      cycle_count_latched <= (others=>'0');
    elsif rising_edge(clk) then
      start_d <= start;
      if (start='1' and start_d='0') then
        counter_running <= '1';
        cycle_counter   <= (others=>'0');
      elsif counter_running='1' then
        if done_fsm='1' then
          counter_running     <= '0';
          cycle_count_latched <= std_logic_vector(cycle_counter);
        else
          cycle_counter <= cycle_counter + 1;
        end if;
      end if;
    end if;
  end process;


  DS_CNT: DigitSplitter
    port map(
      value    => cycle_count_latched,
      hundreds => cnt_h,
      tens     => cnt_t,
      ones     => cnt_u
    );
  SSD_CH: SevenSegmentDecoder port map(digit=>cnt_h, segments=>seg_hundreds);
  SSD_CT: SevenSegmentDecoder port map(digit=>cnt_t, segments=>seg_tens);
  SSD_CU: SevenSegmentDecoder port map(digit=>cnt_u, segments=>seg_units);


  UIX: indexsplitter
    port map(
      value => adjusted_index,
      tens  => idx_h,
      ones  => idx_l
    );
  SEG_IT: SevenSegmentDecoder port map(digit=>idx_h, segments=>seg_index_tens);
  SEG_IO: SevenSegmentDecoder port map(digit=>idx_l, segments=>seg_index_units);

end architecture behavioral;
