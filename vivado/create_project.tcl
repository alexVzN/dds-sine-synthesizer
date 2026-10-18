#   vivado -mode batch -source vivado/create_project.tcl
set root [file normalize [file dirname [info script]]/..]
create_project dds_synth $root/vivado/dds_synth -part xc7z020clg484-1 -force
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

set_property ip_repo_paths $root/rtl/dds_channel [current_project]
update_ip_catalog

proc add_vhdl {fileset files} {
    foreach f $files {
        add_files -fileset $fileset -norecurse $f
        set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets $fileset] $f]
    }
}

add_vhdl sources_1 [glob -nocomplain $root/rtl/dds_channel/*.vhd $root/rtl/summer/*.vhd $root/rtl/dac/*.vhd]
set_property top dds_channel [get_filesets sources_1]

foreach f [glob -nocomplain $root/constraints/*.xdc] {
    add_files -fileset constrs_1 -norecurse $f
}

add_vhdl sim_1 [glob -nocomplain $root/sim/tb_dds_channel.vhd]
if {[llength [glob -nocomplain $root/sim/tb_dds_channel.vhd]]} {
    set_property top tb_dds_channel [get_filesets sim_1]
}

create_fileset -simset sim_broken
set_property SOURCE_SET {} [get_filesets sim_broken]
add_vhdl sim_broken [concat \
    [glob -nocomplain $root/rtl/dds_channel/sine_lut.vhd $root/rtl/dds_channel/dds_channel_regs.vhd $root/rtl/dds_channel/dds_channel.vhd] \
    [glob -nocomplain $root/sim/broken/*.vhd $root/sim/tb_dds_channel.vhd]]
if {[llength [glob -nocomplain $root/sim/tb_dds_channel.vhd]]} {
    set_property top tb_dds_channel [get_filesets sim_broken]
}

create_fileset -simset sim_system
add_vhdl sim_system [glob -nocomplain $root/sim/tb_system*.vhd]
if {[llength [glob -nocomplain $root/sim/tb_system.vhd]]} {
    set_property top tb_system [get_filesets sim_system]
    set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_system]
}

current_fileset -simset [get_filesets sim_1]

if {[file exists $root/rtl/dds_channel/component.xml]} {
    source $root/vivado/create_bd.tcl
}

if {[file exists $root/vitis/dds_firmware/build/dds_firmware.elf]} {
    generate_target all [get_files dds_system.bd]
    source $root/vivado/associate_elf.tcl
}

close_project
