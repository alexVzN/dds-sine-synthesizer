#   vivado -mode batch -source vivado/build_bitstream.tcl
set root [file normalize [file dirname [info script]]/..]
open_project $root/vivado/dds_synth/dds_synth.xpr
source $root/vivado/associate_elf.tcl
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "IMPL_STATUS [get_property STATUS [get_runs impl_1]]"
close_project
