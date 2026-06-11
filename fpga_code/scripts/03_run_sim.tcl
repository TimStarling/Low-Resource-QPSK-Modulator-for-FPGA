# ============================================================
# Vivado xsim script
# Usage:
#   vivado -mode batch -source scripts/03_run_sim.tcl
# ============================================================

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]
set project_xpr [file join $root_dir "fpga_code.xpr"]

if {![file exists $project_xpr]} {
    error "Project not found: $project_xpr. Run scripts/01_create_project.tcl first."
}

open_project $project_xpr

set sim_files [glob -nocomplain [file join $root_dir "sim" "*.sv"]]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 -norecurse $sim_files
}

set_property top tb_qpsk_tx_core [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim

puts "Behavioral simulation completed."
