# ============================================================
# Synthesis and reports script
# Usage:
#   vivado -mode batch -source scripts/02_build_synth.tcl
# ============================================================

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]
set project_xpr [file join $root_dir "fpga_code.xpr"]

if {![file exists $project_xpr]} {
    error "Project not found: $project_xpr. Run scripts/01_create_project.tcl first."
}

open_project $project_xpr

file mkdir [file join $root_dir "reports"]
file mkdir [file join $root_dir "output"]

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed. Check fpga_code.runs/synth_1/runme.log."
}

open_run synth_1
report_utilization -file [file join $root_dir "reports" "post_synth_utilization.rpt"]
report_timing_summary -file [file join $root_dir "reports" "post_synth_timing_summary.rpt"]
write_checkpoint -force [file join $root_dir "output" "post_synth.dcp"]

puts "Synthesis completed."
puts "Reports: [file join $root_dir reports]"
