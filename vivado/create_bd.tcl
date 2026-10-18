#   source vivado/create_bd.tcl   (in the Tcl Console of the open dds_synth project)
set bd dds_system
set n_ch 8

if {[llength [get_files -quiet $bd.bd]]} {
    close_bd_design -quiet [get_bd_designs -quiet $bd]
    export_ip_user_files -of_objects [get_files $bd.bd] -no_script -reset -force -quiet
    remove_files [get_files $bd.bd]
    file delete -force [file dirname [get_property DIRECTORY [current_project]]]/dds_synth/dds_synth.srcs/sources_1/bd/$bd
}
update_ip_catalog
create_bd_design $bd

proc ipdef {name} {
    return [lindex [lsort [get_ipdefs -all -filter "NAME == $name && UPGRADE_VERSIONS == \"\""]] end]
}

create_bd_port -dir I -type clk -freq_hz 50000000 clk
create_bd_port -dir I -type rst rst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports rst_n]
create_bd_port -dir O dac_out
create_bd_port -dir O ovf_led
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 uart

set clk_wiz [create_bd_cell -type ip -vlnv [ipdef clk_wiz] clk_wiz]
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {true} \
] $clk_wiz
connect_bd_net [get_bd_ports clk] [get_bd_pins clk_wiz/clk_in1]

set mb [create_bd_cell -type ip -vlnv [ipdef microblaze] microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { \
    axi_intc {0} axi_periph {Enabled} cache {None} clk {/clk_wiz/clk_out1 (100 MHz)} \
    cores {1} debug_module {Debug Only} ecc {None} local_mem {64KB} preset {None} } $mb
set_property CONFIG.C_USE_HW_MUL {1} $mb

set rst [get_bd_cells -filter {VLNV =~ "*proc_sys_reset*"}]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins $rst/ext_reset_in]
if {![llength [get_bd_nets -quiet -of_objects [get_bd_pins $rst/dcm_locked]]]} {
    connect_bd_net [get_bd_pins clk_wiz/locked] [get_bd_pins $rst/dcm_locked]
}

set gpio [create_bd_cell -type ip -vlnv [ipdef axi_gpio] sync_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH {1} CONFIG.C_ALL_OUTPUTS {1}] $gpio

set uart [create_bd_cell -type ip -vlnv [ipdef axi_uartlite] uart]
set_property -dict [list CONFIG.C_BAUDRATE {230400} CONFIG.C_S_AXI_ACLK_FREQ_HZ {100000000}] $uart
connect_bd_intf_net [get_bd_intf_pins uart/UART] [get_bd_intf_ports uart]

set summer [create_bd_cell -type module -reference summer summer]
set dac    [create_bd_cell -type module -reference sd_dac sd_dac]

set slaves [list [get_bd_intf_pins sync_gpio/S_AXI] [get_bd_intf_pins uart/S_AXI]]
for {set i 0} {$i < $n_ch} {incr i} {
    create_bd_cell -type ip -vlnv user.org:user:dds_channel:1.0 dds_channel_$i
    lappend slaves [get_bd_intf_pins dds_channel_$i/s_axi]
    connect_bd_net [get_bd_pins sync_gpio/gpio_io_o] [get_bd_pins dds_channel_$i/sync]
    connect_bd_net [get_bd_pins dds_channel_$i/sample_out] [get_bd_pins summer/in$i]
}

foreach s $slaves {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config [list         Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto}         Master {/microblaze_0 (Periph)} Slave [get_property PATH $s] ddr_seg {Auto}         intc_ip {Auto} master_apm {0}] $s
}

connect_bd_net [get_bd_pins clk_wiz/clk_out1] [get_bd_pins summer/clk] [get_bd_pins sd_dac/clk]
connect_bd_net [get_bd_pins summer/sum_out] [get_bd_pins sd_dac/din]
connect_bd_net [get_bd_pins sd_dac/dout] [get_bd_ports dac_out]
connect_bd_net [get_bd_pins summer/ovf]  [get_bd_ports ovf_led]

for {set i 0} {$i < $n_ch} {incr i} {
    assign_bd_address -target_address_space /microblaze_0/Data \
        -offset [format 0x%08X [expr {0x44A00000 + $i * 0x10000}]] -range 64K \
        [get_bd_addr_segs dds_channel_$i/s_axi/reg0]
}
assign_bd_address
save_bd_design
source [file dirname [info script]]/add_ila.tcl
regenerate_bd_layout
validate_bd_design
save_bd_design

set wrapper [make_wrapper -files [get_files $bd.bd] -top]
add_files -norecurse $wrapper
set_property top ${bd}_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
