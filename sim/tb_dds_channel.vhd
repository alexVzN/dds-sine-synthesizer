library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_dds_channel is
end entity tb_dds_channel;

architecture sim of tb_dds_channel is
  constant CLK_PERIOD : time := 10 ns;

  constant A_FTW    : std_logic_vector(4 downto 0) := "00000";
  constant A_PHASE  : std_logic_vector(4 downto 0) := "00100";
  constant A_AMP    : std_logic_vector(4 downto 0) := "01000";
  constant A_CTRL   : std_logic_vector(4 downto 0) := "01100";
  constant A_SAMPLE : std_logic_vector(4 downto 0) := "10000";

  constant CTRL_ENABLE : std_logic_vector(31 downto 0) := x"00000001";
  constant CTRL_STEP   : std_logic_vector(31 downto 0) := x"00000002";
  constant CTRL_LOAD   : std_logic_vector(31 downto 0) := x"00000004";
  constant CTRL_OFF    : std_logic_vector(31 downto 0) := x"00000000";

  type int_vec is array (natural range <>) of integer;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal awaddr  : std_logic_vector(4 downto 0) := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal araddr  : std_logic_vector(4 downto 0) := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';

  signal sync       : std_logic := '0';
  signal sample_out : std_logic_vector(15 downto 0);

  signal errors : natural := 0;
begin

  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.dds_channel
    port map (
      s_axi_aclk => clk, s_axi_aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awprot => "000", s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arprot => "000", s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready,
      sync => sync, sample_out => sample_out
    );

  stim : process
    variable rd : std_logic_vector(31 downto 0);

    procedure axi_write(addr : std_logic_vector(4 downto 0); data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      awaddr <= addr; awvalid <= '1';
      wdata  <= data; wvalid  <= '1';
      bready <= '1';
      loop
        wait until rising_edge(clk);
        exit when awready = '1';
      end loop;
      awvalid <= '0'; wvalid <= '0';
      loop
        wait until rising_edge(clk);
        exit when bvalid = '1';
      end loop;
      bready <= '0';
    end procedure;

    procedure axi_read(addr : std_logic_vector(4 downto 0); data : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      araddr <= addr; arvalid <= '1';
      loop
        wait until rising_edge(clk);
        exit when arready = '1';
      end loop;
      arvalid <= '0'; rready <= '1';
      loop
        wait until rising_edge(clk);
        exit when rvalid = '1';
      end loop;
      data := rdata;
      rready <= '0';
    end procedure;

    procedure idle(n : natural) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;

    procedure check(name : string; got, expected : integer) is
    begin
      if got = expected then
        report name & ": " & integer'image(got) & " OK";
      else
        report name & ": got " & integer'image(got) & ", expected " & integer'image(expected) severity error;
        errors <= errors + 1;
      end if;
      wait for 0 ns;
    end procedure;

    procedure read_sample(name : string; expected : integer) is
      variable v : std_logic_vector(31 downto 0);
    begin
      idle(4);
      axi_read(A_SAMPLE, v);
      check(name, to_integer(signed(v(15 downto 0))), expected);
    end procedure;

    procedure step_sequence(name : string; ftw, phase, amp : std_logic_vector(31 downto 0); expected : int_vec) is
    begin
      axi_write(A_CTRL, CTRL_OFF);
      axi_write(A_FTW, ftw);
      axi_write(A_PHASE, phase);
      axi_write(A_AMP, amp);
      axi_write(A_CTRL, CTRL_LOAD);
      read_sample(name & "[0]", expected(expected'low));
      for i in expected'low + 1 to expected'high loop
        axi_write(A_CTRL, CTRL_STEP);
        read_sample(name & "[" & integer'image(i) & "]", expected(i));
      end loop;
    end procedure;

    variable held : integer;
  begin
    aresetn <= '0';
    idle(5);
    aresetn <= '1';
    idle(5);

    axi_write(A_FTW, x"12345678");
    axi_read(A_FTW, rd);
    check("readback FTW", to_integer(unsigned(rd(15 downto 0))), 16#5678#);

    step_sequence("S1", x"40000000", x"00000000", x"00008000",
                  (0, 32767, 0, -32767, 0, 32767, 0, -32767));

    step_sequence("S2", x"20000000", x"40000000", x"00004000",
                  (16383, 11585, 0, -11585, -16384, -11585, 0, 11585));

    step_sequence("S3 steps", x"40000000", x"00000000", x"00008000",
                  (0, 32767, 0, -32767));

    held := to_integer(signed(sample_out));
    idle(20);
    check("S3 hold sample_out", to_integer(signed(sample_out)), held);
    read_sample("S3 hold SAMPLE", -32767);

    axi_write(A_CTRL, CTRL_STEP or CTRL_LOAD);
    axi_read(A_CTRL, rd);
    check("S3 CTRL self-clear", to_integer(unsigned(rd(2 downto 0))), 0);

    axi_write(A_AMP, x"00000000");
    axi_write(A_CTRL, CTRL_ENABLE);
    idle(5);
    for i in 0 to 15 loop
      wait until rising_edge(clk);
      check("S3 AMP=0 [" & integer'image(i) & "]", to_integer(signed(sample_out)), 0);
    end loop;
    axi_write(A_CTRL, CTRL_OFF);

    axi_write(A_AMP, x"0000FFFF");
    axi_write(A_PHASE, x"40000000");
    axi_write(A_CTRL, CTRL_LOAD);
    read_sample("S3 AMP clamp", 32767);

    axi_write(A_AMP, x"00008000");
    axi_write(A_PHASE, x"C0000000");
    wait until rising_edge(clk);
    sync <= '1';
    wait until rising_edge(clk);
    sync <= '0';
    read_sample("S3 sync", -32767);

    idle(5);
    if errors = 0 then
      report "TB RESULT: PASS";
    else
      report "TB RESULT: FAIL (" & integer'image(errors) & " errors)" severity error;
    end if;
    stop;
  end process;

end architecture sim;
