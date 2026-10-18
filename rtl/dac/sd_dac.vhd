library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 1st-order sigma-delta: dout density = (din + 32768) / 65536
entity sd_dac is
  port (
    clk  : in  std_logic;
    din  : in  std_logic_vector(15 downto 0);
    dout : out std_logic
  );
end entity sd_dac;

architecture rtl of sd_dac is
  signal acc : unsigned(16 downto 0) := (others => '0');
begin

  process(clk)
    variable level : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      level := unsigned(not din(15) & din(14 downto 0));
      acc <= ('0' & acc(15 downto 0)) + ('0' & level);
    end if;
  end process;

  dout <= acc(16);

end architecture rtl;
