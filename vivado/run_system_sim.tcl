#   vivado -mode batch -source vivado/run_system_sim.tcl
set root [file normalize [file dirname [info script]]/..]
open_project $root/vivado/dds_synth/dds_synth.xpr
set fs [get_filesets sim_system]
current_fileset -simset $fs
set_property -name {xsim.simulate.runtime} -value {all} -objects $fs
launch_simulation -simset sim_system -mode behavioral
close_sim
current_fileset -simset [get_filesets sim_1]
close_project
