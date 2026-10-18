library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dds_channel is
  generic (
    LUT_ADDR_BITS : natural := 10
  );
  port (
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector(4 downto 0);
    s_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(4 downto 0);
    s_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    sync          : in  std_logic;
    sample_out    : out std_logic_vector(15 downto 0)
  );
end entity dds_channel;

architecture rtl of dds_channel is
  signal ftw, phase, amp, ctrl : std_logic_vector(31 downto 0);
  signal ctrl_wr : std_logic;
  signal sample  : signed(15 downto 0);
  signal step, load : std_logic;
begin

  regs : entity work.dds_channel_regs
    port map (
      s_axi_aclk    => s_axi_aclk,
      s_axi_aresetn => s_axi_aresetn,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awprot  => s_axi_awprot,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arprot  => s_axi_arprot,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready,
      ftw     => ftw,
      phase   => phase,
      amp     => amp,
      ctrl    => ctrl,
      ctrl_wr => ctrl_wr,
      sample  => std_logic_vector(sample)
    );

  step <= ctrl_wr and ctrl(1);
  load <= (ctrl_wr and ctrl(2)) or sync;

  core : entity work.dds_core
    generic map (LUT_ADDR_BITS => LUT_ADDR_BITS)
    port map (
      clk    => s_axi_aclk,
      rstn   => s_axi_aresetn,
      ftw    => unsigned(ftw),
      phase  => unsigned(phase),
      amp    => unsigned(amp(15 downto 0)),
      enable => ctrl(0),
      step   => step,
      load   => load,
      sample => sample
    );

  sample_out <= std_logic_vector(sample);

end architecture rtl;
