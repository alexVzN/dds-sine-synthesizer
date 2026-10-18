#   source vivado/associate_elf.tcl   (re-run after every firmware rebuild)
set root [file normalize [file dirname [info script]]/..]
set elf $root/vitis/dds_firmware/build/dds_firmware.elf
foreach fs {sources_1 sim_system} {
    set fileset [get_filesets $fs]
    foreach old [get_files -quiet -of_objects $fileset -norecurse *.elf] {
        remove_files -fileset $fileset $old
    }
    add_files -fileset $fileset -norecurse $elf
    set elf_file [get_files -of_objects $fileset -norecurse $elf]
    set_property SCOPED_TO_REF dds_system $elf_file
    set_property SCOPED_TO_CELLS microblaze_0 $elf_file
}
set_property USED_IN_SIMULATION 0 [get_files -all *mb_bootloop_le.elf]
