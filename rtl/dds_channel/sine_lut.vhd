library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sine_lut is
  generic (
    ADDR_BITS : natural := 10
  );
  port (
    clk  : in  std_logic;
    addr : in  unsigned(ADDR_BITS - 1 downto 0);
    data : out signed(15 downto 0)
  );
end entity sine_lut;

architecture rtl of sine_lut is
  constant SIZE : natural := 2 ** ADDR_BITS;
  type rom_t is array (0 to SIZE - 1) of signed(15 downto 0);

  function init_rom return rom_t is
    variable r : rom_t;
  begin
    for i in 0 to SIZE - 1 loop
      r(i) := to_signed(integer(round(32767.0 * sin(2.0 * MATH_PI * real(i) / real(SIZE)))), 16);
    end loop;
    return r;
  end function;

  constant ROM : rom_t := init_rom;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      data <= ROM(to_integer(addr));
    end if;
  end process;
end architecture rtl;
