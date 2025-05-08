library ieee;
use ieee.std_logic_1164.all;

entity ControlFSM is
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
end entity;

architecture RTL of ControlFSM is
  type state_t is (IDLE, WRITE, ACCUM, DIVIDE, OUTPUT, WAIT_STATE);
  signal state     : state_t := IDLE;
  signal timer_cnt : integer range 0 to integer(5e8) := 0;
begin
  process(clk, reset)
  begin
    if reset = '1' then
      state     <= IDLE;
      timer_cnt <= 0;
    elsif rising_edge(clk) then
      ram_we    <= '0';
      start_acc <= '0';
      start_div <= '0';
      result_out<= '0';
      busy      <= '1';

      case state is
        when IDLE =>
          busy <= '0';
          if start = '1' then
            state <= WRITE;
          end if;

        when WRITE =>
          ram_we <= '1';
          if write_req = '0' then
            state <= ACCUM;
          end if;

        when ACCUM =>
          start_acc <= '1';
          if acc_done = '1' then
            state <= DIVIDE;
          end if;

        when DIVIDE =>
          start_div <= '1';
          if div_done = '1' then
            state <= OUTPUT;
          end if;

        when OUTPUT =>
          result_out <= '1';
          if timer_cnt < 500000000 then
            timer_cnt <= timer_cnt + 1;
          else
            state <= IDLE;
          end if;

        when WAIT_STATE =>
          state <= IDLE;

      end case;
    end if;
  end process;
end architecture RTL;
