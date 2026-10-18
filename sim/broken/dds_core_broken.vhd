library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- BROKEN COPY: LUT addressed with acc + ftw (one step ahead)
entity dds_core is
  generic (
    LUT_ADDR_BITS : natural := 10
  );
  port (
    clk    : in  std_logic;
    rstn   : in  std_logic;
    ftw    : in  unsigned(31 downto 0);
    phase  : in  unsigned(31 downto 0);
    amp    : in  unsigned(15 downto 0);
    enable : in  std_logic;
    step   : in  std_logic;
    load   : in  std_logic;
    sample : out signed(15 downto 0)
  );
end entity dds_core;

architecture rtl of dds_core is
  constant AMP_MAX : unsigned(15 downto 0) := x"8000";

  signal acc      : unsigned(31 downto 0) := (others => '0');
  signal lut_q    : signed(15 downto 0);
  signal amp_q    : signed(16 downto 0) := (others => '0');
  signal sample_q : signed(15 downto 0) := (others => '0');
  signal acc_next : unsigned(31 downto 0);
  signal lut_addr : unsigned(LUT_ADDR_BITS - 1 downto 0);
begin

  phase_acc : process(clk)
  begin
    if rising_edge(clk) then
      if rstn = '0' then
        acc <= (others => '0');
      elsif load = '1' then
        acc <= phase;
      elsif enable = '1' or step = '1' then
        acc <= acc + ftw;
      end if;
    end if;
  end process;

  acc_next <= acc + ftw;
  lut_addr <= acc_next(31 downto 32 - LUT_ADDR_BITS);

  lut : entity work.sine_lut
    generic map (ADDR_BITS => LUT_ADDR_BITS)
    port map (
      clk  => clk,
      addr => lut_addr,
      data => lut_q
    );

  amplitude : process(clk)
  begin
    if rising_edge(clk) then
      if amp > AMP_MAX then
        amp_q <= signed('0' & AMP_MAX);
      else
        amp_q <= signed('0' & amp);
      end if;

      if rstn = '0' then
        sample_q <= (others => '0');
      else
        sample_q <= resize(shift_right(lut_q * amp_q, 15), 16);
      end if;
    end if;
  end process;

  sample <= sample_q;

end architecture rtl;
