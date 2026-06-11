# ============================================================
# Vivado project creation script
# Usage:
#   vivado -mode batch -source scripts/01_create_project.tcl
# ============================================================

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]

set project_name "fpga_code"
set project_dir  $root_dir
set part_number  "xc7s6-1ftgb196"
set top_module   "qpsk_top"

puts "Project root: $root_dir"
puts "Target part : $part_number"

set matched_parts [get_parts -quiet $part_number]
if {[llength $matched_parts] == 0} {
    error "Target part '$part_number' is not available in this Vivado installation."
}

create_project $project_name $project_dir -part $part_number -force

set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property target_language Verilog [current_project]

set hdl_files [glob -nocomplain [file join $root_dir "hdl" "*.v"]]
append hdl_files " "
append hdl_files [glob -nocomplain [file join $root_dir "hdl" "*.sv"]]
set hdl_files [string trim $hdl_files]
if {$hdl_files ne ""} {
    add_files -fileset sources_1 $hdl_files
}

set xdc_files [glob -nocomplain [file join $root_dir "constraints" "*.xdc"]]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
}

set sim_files [glob -nocomplain [file join $root_dir "sim" "*.sv"]]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 -norecurse $sim_files
}

set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1
if {[llength $sim_files] > 0} {
    set_property top tb_qpsk_tx_core [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

puts "Vivado project created: [file join $project_dir $project_name.xpr]"
