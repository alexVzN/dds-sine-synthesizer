library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity summer is
  port (
    clk     : in  std_logic;
    in0     : in  std_logic_vector(15 downto 0);
    in1     : in  std_logic_vector(15 downto 0);
    in2     : in  std_logic_vector(15 downto 0);
    in3     : in  std_logic_vector(15 downto 0);
    in4     : in  std_logic_vector(15 downto 0);
    in5     : in  std_logic_vector(15 downto 0);
    in6     : in  std_logic_vector(15 downto 0);
    in7     : in  std_logic_vector(15 downto 0);
    sum_out : out std_logic_vector(15 downto 0);
    ovf     : out std_logic
  );
end entity summer;

architecture rtl of summer is
  constant MAX_OUT : integer := 32767;
  constant MIN_OUT : integer := -32768;

  type pair_sums_t is array (0 to 3) of signed(16 downto 0);

  signal pair_sums : pair_sums_t := (others => (others => '0'));
  signal sum_full  : signed(18 downto 0) := (others => '0');
  signal sum_q     : signed(15 downto 0) := (others => '0');
  signal ovf_q     : std_logic := '0';

  function pair(a, b : std_logic_vector(15 downto 0)) return signed is
  begin
    return resize(signed(a), 17) + resize(signed(b), 17);
  end function;
begin

  process(clk)
  begin
    if rising_edge(clk) then
      pair_sums <= (pair(in0, in1), pair(in2, in3), pair(in4, in5), pair(in6, in7));

      sum_full <= (resize(pair_sums(0), 19) + resize(pair_sums(1), 19))
                + (resize(pair_sums(2), 19) + resize(pair_sums(3), 19));

      if sum_full > MAX_OUT then
        sum_q <= to_signed(MAX_OUT, 16);
        ovf_q <= '1';
      elsif sum_full < MIN_OUT then
        sum_q <= to_signed(MIN_OUT, 16);
        ovf_q <= '1';
      else
        sum_q <= resize(sum_full, 16);
        ovf_q <= '0';
      end if;
    end if;
  end process;

  sum_out <= std_logic_vector(sum_q);
  ovf     <= ovf_q;

end architecture rtl;
