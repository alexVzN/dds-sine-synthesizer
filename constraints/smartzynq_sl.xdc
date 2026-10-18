set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports clk]

set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS33} [get_ports rst_n]

set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports dac_out]

set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS33} [get_ports ovf_led]

set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
