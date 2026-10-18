#   vivado -mode batch -source vivado/export_xsa.tcl
set root [file normalize [file dirname [info script]]/..]
open_project $root/vivado/dds_synth/dds_synth.xpr
generate_target all [get_files dds_system.bd]
write_hw_platform -fixed -force -file $root/vivado/dds_system.xsa
close_project
