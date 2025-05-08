library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity getpercentilefsm is
    port(
      clk, reset, enable   : in  std_logic;
      multdone, divdone     : in  std_logic;
      thresholdmet, countdone : in std_logic;
      startmult, startdiv  : out std_logic;
      enablecount, startacc: out std_logic;
      done                  : out std_logic;
      fsm_state             : out std_logic_vector(2 downto 0)
    );
end getpercentilefsm;

architecture behavioral of getpercentilefsm is
  type state_type is (IDLE, CALCULATE, ACCUMULATE, DONE_STATE);
  signal state, next_state : state_type;
begin

  -- state register
  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then
        state <= IDLE;
      else
        state <= next_state;
      end if;
    end if;
  end process;

  -- next‑state & outputs
  process(state, enable, multdone, divdone, thresholdmet, countdone)
  begin
    -- defaults
    startmult    <= '0';
    startdiv     <= '0';
    enablecount  <= '0';
    startacc     <= '0';
    done         <= '0';
    next_state   <= state;

    case state is
      when IDLE =>
        if enable='1' then
          next_state <= CALCULATE;
        end if;

      when CALCULATE =>
        -- first start multiplier until done
        if multdone='0' then
          startmult <= '1';
        -- then start divider until done
        elsif divdone='0' then
          startdiv <= '1';
        else
          next_state <= ACCUMULATE;
        end if;

      when ACCUMULATE =>
        enablecount <= '1';
        startacc    <= '1';
        if thresholdmet='1' or countdone='1' then
          next_state <= DONE_STATE;
        end if;

      when DONE_STATE =>
        done <= '1';
        next_state <= IDLE;

    end case;
  end process;

  fsm_state <= std_logic_vector(to_unsigned(state'pos(state),3));

end behavioral;
