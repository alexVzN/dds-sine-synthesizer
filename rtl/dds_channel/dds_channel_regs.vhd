library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dds_channel_regs is
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

    ftw      : out std_logic_vector(31 downto 0);
    phase    : out std_logic_vector(31 downto 0);
    amp      : out std_logic_vector(31 downto 0);
    ctrl     : out std_logic_vector(31 downto 0);
    ctrl_wr  : out std_logic;
    sample   : in  std_logic_vector(15 downto 0)
  );
end entity dds_channel_regs;

architecture rtl of dds_channel_regs is
  constant ADDR_LSB : natural := 2;
  constant ADDR_MSB : natural := 4;

  type state_t is (IDLE, ADDR, DATA);
  signal wr_state, rd_state : state_t := IDLE;

  signal awaddr_q : std_logic_vector(4 downto 0) := (others => '0');
  signal araddr_q : std_logic_vector(4 downto 0) := (others => '0');
  signal awready, wready, bvalid, arready, rvalid : std_logic := '0';
  signal wr_index : std_logic_vector(ADDR_MSB downto ADDR_LSB);

  signal reg_ftw, reg_phase, reg_amp, reg_ctrl : std_logic_vector(31 downto 0) := (others => '0');
  signal ctrl_wr_q : std_logic := '0';

  procedure write_bytes(signal reg : inout std_logic_vector(31 downto 0);
                        data : std_logic_vector(31 downto 0);
                        strb : std_logic_vector(3 downto 0)) is
  begin
    for i in 0 to 3 loop
      if strb(i) = '1' then
        reg(8*i + 7 downto 8*i) <= data(8*i + 7 downto 8*i);
      end if;
    end loop;
  end procedure;
begin
  s_axi_awready <= awready;
  s_axi_wready  <= wready;
  s_axi_bresp   <= "00";
  s_axi_bvalid  <= bvalid;
  s_axi_arready <= arready;
  s_axi_rresp   <= "00";
  s_axi_rvalid  <= rvalid;

  ftw     <= reg_ftw;
  phase   <= reg_phase;
  amp     <= reg_amp;
  ctrl    <= reg_ctrl;
  ctrl_wr <= ctrl_wr_q;

  wr_index <= s_axi_awaddr(ADDR_MSB downto ADDR_LSB) when s_axi_awvalid = '1'
              else awaddr_q(ADDR_MSB downto ADDR_LSB);

  write_fsm : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        awready <= '0'; wready <= '0'; bvalid <= '0';
        wr_state <= IDLE;
      else
        case wr_state is
          when IDLE =>
            awready <= '1';
            wready  <= '1';
            wr_state <= ADDR;
          when ADDR =>
            if s_axi_awvalid = '1' and awready = '1' then
              awaddr_q <= s_axi_awaddr;
              if s_axi_wvalid = '1' then
                bvalid <= '1';
              else
                awready <= '0';
                wr_state <= DATA;
                if s_axi_bready = '1' and bvalid = '1' then bvalid <= '0'; end if;
              end if;
            elsif s_axi_bready = '1' and bvalid = '1' then
              bvalid <= '0';
            end if;
          when DATA =>
            if s_axi_wvalid = '1' then
              bvalid  <= '1';
              awready <= '1';
              wr_state <= ADDR;
            elsif s_axi_bready = '1' and bvalid = '1' then
              bvalid <= '0';
            end if;
        end case;
      end if;
    end if;
  end process;

  reg_write : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      ctrl_wr_q <= '0';
      if s_axi_aresetn = '0' then
        reg_ftw <= (others => '0'); reg_phase <= (others => '0');
        reg_amp <= (others => '0'); reg_ctrl  <= (others => '0');
      else
        reg_ctrl(2 downto 1) <= "00";
        if s_axi_wvalid = '1' then
          case wr_index is
            when "000" => write_bytes(reg_ftw,   s_axi_wdata, s_axi_wstrb);
            when "001" => write_bytes(reg_phase, s_axi_wdata, s_axi_wstrb);
            when "010" => write_bytes(reg_amp,   s_axi_wdata, s_axi_wstrb);
            when "011" => write_bytes(reg_ctrl,  s_axi_wdata, s_axi_wstrb);
                          ctrl_wr_q <= '1';
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  read_fsm : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        arready <= '0'; rvalid <= '0';
        rd_state <= IDLE;
      else
        case rd_state is
          when IDLE =>
            arready <= '1';
            rd_state <= ADDR;
          when ADDR =>
            if s_axi_arvalid = '1' and arready = '1' then
              araddr_q <= s_axi_araddr;
              rvalid   <= '1';
              arready  <= '0';
              rd_state <= DATA;
            end if;
          when DATA =>
            if rvalid = '1' and s_axi_rready = '1' then
              rvalid   <= '0';
              arready  <= '1';
              rd_state <= ADDR;
            end if;
        end case;
      end if;
    end if;
  end process;

  with araddr_q(ADDR_MSB downto ADDR_LSB) select s_axi_rdata <=
    reg_ftw            when "000",
    reg_phase          when "001",
    reg_amp            when "010",
    reg_ctrl           when "011",
    x"0000" & sample   when "100",
    (others => '0')    when others;

end architecture rtl;
