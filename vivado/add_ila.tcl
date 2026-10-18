#   source vivado/add_ila.tcl   (in the open dds_synth project; also sourced by create_bd.tcl)
open_bd_design [get_files dds_system.bd]
delete_bd_objs -quiet [get_bd_cells -quiet ila] [get_bd_cells -quiet ila_flags]

set ila [create_bd_cell -type ip -vlnv [lindex [lsort [get_ipdefs -all -filter {NAME == ila}]] end] ila]
set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_PROBE0_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE2_WIDTH {16} \
    CONFIG.C_PROBE3_WIDTH {16} \
    CONFIG.C_PROBE4_WIDTH {2} \
    CONFIG.C_ENABLE_ILA_AXI_MON {false} \
] $ila

connect_bd_net [get_bd_pins clk_wiz/clk_out1]         [get_bd_pins ila/clk]
connect_bd_net [get_bd_pins summer/sum_out]           [get_bd_pins ila/probe0]
connect_bd_net [get_bd_pins dds_channel_0/sample_out] [get_bd_pins ila/probe1]
connect_bd_net [get_bd_pins dds_channel_1/sample_out] [get_bd_pins ila/probe2]
connect_bd_net [get_bd_pins dds_channel_2/sample_out] [get_bd_pins ila/probe3]
set flags [create_bd_cell -type ip -vlnv [lindex [lsort [get_ipdefs -all -filter {NAME == xlconcat}]] end] ila_flags]
set_property CONFIG.NUM_PORTS {2} $flags
connect_bd_net [get_bd_pins sync_gpio/gpio_io_o]      [get_bd_pins ila_flags/In0]
connect_bd_net [get_bd_pins summer/ovf]               [get_bd_pins ila_flags/In1]
connect_bd_net [get_bd_pins ila_flags/dout]           [get_bd_pins ila/probe4]

validate_bd_design
save_bd_design
