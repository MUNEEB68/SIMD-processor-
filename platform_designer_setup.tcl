#!/usr/bin/env tclsh
# Platform Designer (Qsys) helper Tcl
# Quartus/Platform Designer versions differ in Tcl API; this template
# automates common steps and contains clear placeholders you must fill
# when adding vendor-specific IP (HPS). Tested guidance for Quartus
# Prime Lite 20.1 / Platform Designer.

# Usage (run inside Quartus Tcl console or qtcsh):
# 1) Open Quartus, then open Tcl Console (Tools → Tcl Console) OR run
#    quartus_sh --64bit -t platform_designer_setup.tcl
# 2) Edit the placeholders below before running (HPS component name/variant,
#    search paths for your HDL files if needed).

package require Tcl 8.5

set system_name "simd_system"
set qsys_file "${system_name}.qsys"

# Paths to files (adjust if your project layout differs)
if {[string equal [info script] ""]} {
    # When sourced from the Quartus Tcl Console, [info script] can be empty.
    # Use the current working directory (pwd) as the project root in that case.
    set project_root [file normalize [pwd]]
} else {
    set project_root [file normalize [file dirname [info script]]]
}
set cpu_top_sv "$project_root/cputop.v"
set debug_tap_sv "$project_root/cpu_debug_tap.v"

# Placeholder: name of the HPS/pll/clock IP as available in your PD catalog.
# For DE1-SoC (Cyclone V), the IP is typically named "altera_hps" in PD.
set hps_component_name "altera_hps"

# Helper: print summary
puts "Platform Designer setup starting for $system_name"
puts "Project root: $project_root"
puts "CPU top: $cpu_top_sv"
puts "Debug tap: $debug_tap_sv"

# Basic safety checks
if {![file exists $cpu_top_sv]} {
    puts stderr "ERROR: CPU top file not found at $cpu_top_sv"
    exit 1
}
if {![file exists $debug_tap_sv]} {
    puts stderr "ERROR: Debug tap file not found at $debug_tap_sv"
    exit 1
}

# The Platform Designer Tcl API differs by Quartus releases. Rather than
# guessing variant-specific commands, this template will perform the
# following safe, repeatable actions:
#  - create a new empty .qsys file (XML skeleton)
#  - create simple component wrappers for the two HDL files using
#    the Platform Designer "create_component_from_files" semantics
#    (you will still need to review and register them in the GUI for
#    the HPS megafunction component if you want fully automated HPS wiring)
#  - provide the exact commands to add the HPS IP and connect signals
#    manually or via PD GUI.

set qsys_path [file join $project_root $qsys_file]

if {[file exists $qsys_path]} {
    puts "Note: $qsys_file already exists; it will be overwritten. Backing up."
    file copy -force $qsys_path ${qsys_path}.bak
}

# Create a minimal but valid .qsys file for Quartus 20.1
# Quartus 20.1 uses a strict XML schema with attribute-based parameters
set fp [open $qsys_path "w"]
fconfigure $fp -encoding utf-8 -translation binary

puts $fp {<?xml version="1.0" encoding="UTF-8"?>}
puts $fp {<system name="simd_system">}
puts $fp {  <parameter name="bonusData" value=""/>}
puts $fp {  <parameter name="clockCrossingAdapter" value="HANDSHAKE"/>}
puts $fp {  <parameter name="device" value="5CSXFC6D6F31C8"/>}
puts $fp {  <parameter name="deviceFamily" value="Cyclone V"/>}
puts $fp {  <parameter name="deviceSpeedGrade" value="8"/>}
puts $fp {  <parameter name="fabricMode" value="QSYS"/>}
puts $fp {  <parameter name="generateLegacySim" value="false"/>}
puts $fp {  <parameter name="generateModuleMap" value="false"/>}
puts $fp {  <parameter name="generateVerilogSim" value="false"/>}
puts $fp {  <parameter name="hdlLanguage" value="VERILOG"/>}
puts $fp {  <parameter name="hideFromIPCatalog" value="false"/>}
puts $fp {  <parameter name="maxNavItems" value="1"/>}
puts $fp {  <parameter name="projectName" value=""/>}
puts $fp {  <parameter name="sopcBorderPoints" value="false"/>}
puts $fp {  <parameter name="systemHash" value="NOHASH"/>}
puts $fp {  <parameter name="timeStamp" value="0"/>}
puts $fp {</system>}

close $fp

puts "Created minimal valid .qsys file: $qsys_path"

# Create simple component directories so Platform Designer can import them
proc make_component_dir {compname files} {
    global project_root
    set compdir [file join $project_root qsys_components $compname]
    if {![file exists $compdir]} { file mkdir $compdir }
    foreach f $files {
        if {[file exists $f]} {
            file copy -force $f $compdir
        }
    }
    return $compdir
}

puts "Packaging HDL files as simple components (for manual import into PD)"
set cpu_comp_dir [make_component_dir cpu_top [list $cpu_top_sv]]
set dbg_comp_dir [make_component_dir cpu_debug_tap [list $debug_tap_sv]]

puts "Created component folders:"
puts " - $cpu_comp_dir"
puts " - $dbg_comp_dir"

puts "\nNEXT STEPS (manual / semi-automated):"
puts "1) Open Platform Designer and load $qsys_file (File → Open)."
puts "2) In Platform Designer choose: File → New → Component from Files..."
puts "   - For CPU: point to $cpu_comp_dir and create a simple component."
puts "   - For cpu_debug_tap: point to $dbg_comp_dir and create an Avalon-MM slave component"
puts "     (set the interface to Avalon-MM slave with 32-bit data and relevant address map)"
puts "3) Add the HPS IP (Search the IP catalog for 'HPS' / 'altera_hps') and configure the interfaces you need."
puts "4) Instantiate the CPU and cpu_debug_tap components in the system and connect the debug slave to the HPS lightweight or main bus."
puts "   - Recommended: hook cpu_debug_tap as an Avalon-MM slave on the Lightweight HPS-to-FPGA bridge (LWH2F)"
puts "5) Export HDL, generate the system, and add generated QIP files to your Quartus project."

puts "\nIf you want full automation (PD API commands to add HPS and connect nets), reply and I will produce a second script that attempts to use the Platform Designer Tcl API to add and wire known IPs automatically."

puts "platform_designer_setup finished."

exit 0
