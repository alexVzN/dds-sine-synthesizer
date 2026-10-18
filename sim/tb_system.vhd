library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_system is
end entity tb_system;

architecture sim of tb_system is
  constant CLK_PERIOD   : time := 20 ns;
  constant BAUD         : natural := 230400;
  constant BIT_TIME     : time := 1 sec / BAUD;
  constant LINE_TIMEOUT : time := 10 ms;
  constant LINE_LEN     : natural := 160;

  subtype word_t is std_logic_vector(31 downto 0);
  type word_arr is array (0 to 7) of word_t;
  type int_arr  is array (0 to 7) of integer;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal dac_out  : std_logic;
  signal ovf_led  : std_logic;
  signal uart_rxd : std_logic := '1';
  signal uart_txd : std_logic;

  signal rx_line  : string(1 to LINE_LEN);
  signal rx_len   : natural := 0;
  signal rx_count : natural := 0;

  signal ftw, phase, amp, ctrl : word_arr;
  signal sample : int_arr;

  signal errors : natural := 0;

  function contains(haystack : string; needle : string) return boolean is
  begin
    if needle'length > haystack'length then
      return false;
    end if;
    for i in haystack'low to haystack'high - needle'length + 1 loop
      if haystack(i to i + needle'length - 1) = needle then
        return true;
      end if;
    end loop;
    return false;
  end function;

  function hex(v : word_t) return string is
  begin
    return to_hstring(v);
  end function;
begin

  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.dds_system_wrapper
    port map (
      clk      => clk,
      rst_n    => rst_n,
      dac_out  => dac_out,
      ovf_led  => ovf_led,
      uart_rxd => uart_rxd,
      uart_txd => uart_txd
    );

  ftw(0) <= <<signal .tb_system.dut.dds_system_i.dds_channel_0.U0.regs.reg_ftw   : word_t>>;
  ftw(1) <= <<signal .tb_system.dut.dds_system_i.dds_channel_1.U0.regs.reg_ftw   : word_t>>;
  ftw(2) <= <<signal .tb_system.dut.dds_system_i.dds_channel_2.U0.regs.reg_ftw   : word_t>>;
  ftw(3) <= <<signal .tb_system.dut.dds_system_i.dds_channel_3.U0.regs.reg_ftw   : word_t>>;
  ftw(4) <= <<signal .tb_system.dut.dds_system_i.dds_channel_4.U0.regs.reg_ftw   : word_t>>;
  ftw(5) <= <<signal .tb_system.dut.dds_system_i.dds_channel_5.U0.regs.reg_ftw   : word_t>>;
  ftw(6) <= <<signal .tb_system.dut.dds_system_i.dds_channel_6.U0.regs.reg_ftw   : word_t>>;
  ftw(7) <= <<signal .tb_system.dut.dds_system_i.dds_channel_7.U0.regs.reg_ftw   : word_t>>;
  phase(0) <= <<signal .tb_system.dut.dds_system_i.dds_channel_0.U0.regs.reg_phase : word_t>>;
  phase(1) <= <<signal .tb_system.dut.dds_system_i.dds_channel_1.U0.regs.reg_phase : word_t>>;
  phase(2) <= <<signal .tb_system.dut.dds_system_i.dds_channel_2.U0.regs.reg_phase : word_t>>;
  phase(3) <= <<signal .tb_system.dut.dds_system_i.dds_channel_3.U0.regs.reg_phase : word_t>>;
  phase(4) <= <<signal .tb_system.dut.dds_system_i.dds_channel_4.U0.regs.reg_phase : word_t>>;
  phase(5) <= <<signal .tb_system.dut.dds_system_i.dds_channel_5.U0.regs.reg_phase : word_t>>;
  phase(6) <= <<signal .tb_system.dut.dds_system_i.dds_channel_6.U0.regs.reg_phase : word_t>>;
  phase(7) <= <<signal .tb_system.dut.dds_system_i.dds_channel_7.U0.regs.reg_phase : word_t>>;
  amp(0) <= <<signal .tb_system.dut.dds_system_i.dds_channel_0.U0.regs.reg_amp   : word_t>>;
  amp(1) <= <<signal .tb_system.dut.dds_system_i.dds_channel_1.U0.regs.reg_amp   : word_t>>;
  amp(2) <= <<signal .tb_system.dut.dds_system_i.dds_channel_2.U0.regs.reg_amp   : word_t>>;
  amp(3) <= <<signal .tb_system.dut.dds_system_i.dds_channel_3.U0.regs.reg_amp   : word_t>>;
  amp(4) <= <<signal .tb_system.dut.dds_system_i.dds_channel_4.U0.regs.reg_amp   : word_t>>;
  amp(5) <= <<signal .tb_system.dut.dds_system_i.dds_channel_5.U0.regs.reg_amp   : word_t>>;
  amp(6) <= <<signal .tb_system.dut.dds_system_i.dds_channel_6.U0.regs.reg_amp   : word_t>>;
  amp(7) <= <<signal .tb_system.dut.dds_system_i.dds_channel_7.U0.regs.reg_amp   : word_t>>;
  ctrl(0) <= <<signal .tb_system.dut.dds_system_i.dds_channel_0.U0.regs.reg_ctrl : word_t>>;
  ctrl(1) <= <<signal .tb_system.dut.dds_system_i.dds_channel_1.U0.regs.reg_ctrl : word_t>>;
  ctrl(2) <= <<signal .tb_system.dut.dds_system_i.dds_channel_2.U0.regs.reg_ctrl : word_t>>;
  ctrl(3) <= <<signal .tb_system.dut.dds_system_i.dds_channel_3.U0.regs.reg_ctrl : word_t>>;
  ctrl(4) <= <<signal .tb_system.dut.dds_system_i.dds_channel_4.U0.regs.reg_ctrl : word_t>>;
  ctrl(5) <= <<signal .tb_system.dut.dds_system_i.dds_channel_5.U0.regs.reg_ctrl : word_t>>;
  ctrl(6) <= <<signal .tb_system.dut.dds_system_i.dds_channel_6.U0.regs.reg_ctrl : word_t>>;
  ctrl(7) <= <<signal .tb_system.dut.dds_system_i.dds_channel_7.U0.regs.reg_ctrl : word_t>>;
  sample(0) <= to_integer(signed(<<signal .tb_system.dut.dds_system_i.dds_channel_0.U0.sample_out : std_logic_vector(15 downto 0)>>));

  uart_rx : process
    variable buf : string(1 to LINE_LEN);
    variable len : natural := 0;
    variable byte_v : std_logic_vector(7 downto 0);
    variable c : character;
  begin
    wait until falling_edge(uart_txd);
    wait for BIT_TIME / 2;
    for i in 0 to 7 loop
      wait for BIT_TIME;
      byte_v(i) := uart_txd;
    end loop;
    wait for BIT_TIME;
    c := character'val(to_integer(unsigned(byte_v)));
    if c = LF then
      rx_line <= buf;
      rx_len <= len;
      rx_count <= rx_count + 1;
      report "uart> " & buf(1 to len);
      len := 0;
      buf := (others => ' ');
    elsif c /= CR and len < LINE_LEN then
      len := len + 1;
      buf(len) := c;
    end if;
  end process;

  stim : process
    procedure fail(msg : string) is
    begin
      report msg severity error;
      errors <= errors + 1;
      wait for 0 ns;
    end procedure;

    procedure uart_send_char(c : character) is
      constant b : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(character'pos(c), 8));
    begin
      uart_rxd <= '0';
      wait for BIT_TIME;
      for i in 0 to 7 loop
        uart_rxd <= b(i);
        wait for BIT_TIME;
      end loop;
      uart_rxd <= '1';
      wait for BIT_TIME;
    end procedure;

    procedure send_line(s : string) is
    begin
      report "term> " & s;
      for i in s'range loop
        uart_send_char(s(i));
      end loop;
      uart_send_char(CR);
    end procedure;

    procedure expect_line(needle : string) is
      variable deadline : time := now + LINE_TIMEOUT;
    begin
      loop
        wait on rx_count for deadline - now;
        if now >= deadline then
          fail("timeout waiting for '" & needle & "'");
          return;
        end if;
        exit when contains(rx_line(1 to rx_len), needle);
      end loop;
    end procedure;

    procedure expect_reg(name : string; got, expected : word_t) is
    begin
      if got /= expected then
        fail(name & " = 0x" & hex(got) & ", expected 0x" & hex(expected));
      end if;
    end procedure;

    procedure expect_channel(ch : natural; f, p, a : word_t; enabled : boolean) is
      constant tag : string := "ch" & integer'image(ch);
    begin
      expect_reg(tag & " FTW", ftw(ch), f);
      expect_reg(tag & " PHASE", phase(ch), p);
      expect_reg(tag & " AMP", amp(ch), a);
      if (ctrl(ch)(0) = '1') /= enabled then
        fail(tag & " enable = " & std_logic'image(ctrl(ch)(0)));
      end if;
    end procedure;

    procedure expect_off(first : natural) is
    begin
      for ch in first to 7 loop
        expect_channel(ch, x"00000000", x"00000000", x"00000000", false);
      end loop;
    end procedure;

    procedure expect_peak(expected : integer; window : time) is
      variable peak : integer := 0;
      variable deadline : time := now + window;
    begin
      while now < deadline loop
        wait on sample for deadline - now;
        if sample(0) > peak then
          peak := sample(0);
        end if;
      end loop;
      if peak /= expected then
        fail("ch0 peak = " & integer'image(peak) & ", expected " & integer'image(expected));
      end if;
    end procedure;

    procedure section(name : string) is
    begin
      report "==== " & name;
    end procedure;
  begin
    rst_n <= '0';
    wait for 1 us;
    rst_n <= '1';

    section("boot and self-test");
    expect_line("self-test: PASS");
    expect_line("type 'help'");

    section("plain sine 1 MHz, 1 V");
    send_line("1000:1");
    expect_line("ch0  1000.000 kHz  1.000 V  0.000 deg");
    expect_channel(0, x"028F5C29", x"00000000", x"00004D93", true);
    expect_off(1);
    expect_peak(19858, 2 us);

    section("same sine, amplitude 0,5 V (comma separator)");
    send_line("1000:0,5");
    expect_line("ch0  1000.000 kHz  0.500 V  0.000 deg");
    expect_channel(0, x"028F5C29", x"00000000", x"000026CA", true);
    expect_off(1);
    expect_peak(9929, 2 us);

    section("AM: carrier 1 MHz 0.8 V, 100 kHz modulation, m = 0.5");
    send_line("1000:0.8 900:0.2 1100:0.2");
    expect_line("ch2  1100.000 kHz  0.200 V  0.000 deg");
    expect_channel(0, x"028F5C29", x"00000000", x"00003E10", true);
    expect_channel(1, x"024DD2F2", x"00000000", x"00000F84", true);
    expect_channel(2, x"02D0E560", x"00000000", x"00000F84", true);
    expect_off(3);
    expect_peak(15887, 2 us);
    if ovf_led /= '0' then
      fail("overflow flag set");
    end if;

    section("amplitude sum above full scale is rejected");
    send_line("1:1 2:0.7");
    expect_line("warning: amplitude sum 1.700 V");
    expect_channel(0, x"028F5C29", x"00000000", x"00003E10", true);

    section("channel amplitude above 1 V is rejected");
    send_line("1:1.2");
    expect_line("error: tone 1: amplitude above 1.000 V");
    expect_channel(0, x"028F5C29", x"00000000", x"00003E10", true);

    section("malformed tone is rejected");
    send_line("1:abc");
    expect_line("error: tone 1: expected");

    section("all channels off");
    send_line("off");
    expect_line("all channels off");
    expect_off(0);

    wait for 10 us;
    if errors = 0 then
      report "SYSTEM TB RESULT: PASS";
    else
      report "SYSTEM TB RESULT: FAIL (" & integer'image(errors) & " errors)" severity error;
    end if;
    stop;
  end process;

end architecture sim;
