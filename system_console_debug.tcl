# System Console helper for reading cpu_debug_tap over JTAG
# Reads latched post-instruction snapshots
# Usage in System Console: source system_console_debug.tcl

proc parse_cpu_debug {regs} {
    set reg0 [lindex $regs 0]
    set reg1 [lindex $regs 1]
    set reg2 [lindex $regs 2]
    set reg3 [lindex $regs 3]
    set reg4 [lindex $regs 4]
    set reg5 [lindex $regs 5]
    set reg6 [lindex $regs 6]
    set reg7 [lindex $regs 7]
    set reg8 [lindex $regs 8]

    # reg0 layout (from cpu_debug_tap.v)
    # [9:0] instruction_address
    # [15:10] opcode
    # [16] data_R
    # [17] data_W
    # [18] done
    set pc [expr {$reg0 & 0x3FF}]
    set opcode [expr {($reg0 >> 10) & 0x3F}]
    set data_R [expr {($reg0 >> 16) & 0x1}]
    set data_W [expr {($reg0 >> 17) & 0x1}]
    set done [expr {($reg0 >> 18) & 0x1}]

    # reg1 layout
    # [9:0] data_address
    # [25:10] data_out
    set data_addr [expr {$reg1 & 0x3FF}]
    set data_out [expr {($reg1 >> 10) & 0xFFFF}]

    # reg2 layout
    # [17:0] instruction_in
    set instr [expr {$reg2 & 0x3FFFF}]

    # reg3 layout
    # [15:0] snapshot_counter
    # sample_counter increments when instruction_address changes
    set sample [expr {$reg3 & 0xFFFF}]

    # reg4-7 layout
    # [15:0] H0..H3
    set h0 [expr {$reg4 & 0xFFFF}]
    set h1 [expr {$reg5 & 0xFFFF}]
    set h2 [expr {$reg6 & 0xFFFF}]
    set h3 [expr {$reg7 & 0xFFFF}]

    # reg8 layout
    # [15:0] fifo_count
    # [16] fifo_overflow
    set fifo_count [expr {$reg8 & 0xFFFF}]
    set fifo_overflow [expr {($reg8 >> 16) & 0x1}]

    return [list $reg0 $reg1 $reg2 $reg3 $pc $opcode $data_R $data_W $done \
                 $data_addr $data_out $instr $sample $h0 $h1 $h2 $h3 \
                 $fifo_count $fifo_overflow]
}

proc print_cpu_debug {parsed} {
    lassign $parsed reg0 reg1 reg2 reg3 pc opcode data_R data_W done \
                    data_addr data_out instr sample h0 h1 h2 h3 \
                    fifo_count fifo_overflow

    puts [format "reg0=0x%08X reg1=0x%08X reg2=0x%08X reg3=0x%08X" $reg0 $reg1 $reg2 $reg3]
    puts [format "PC=%d opcode=%d data_R=%d data_W=%d done=%d" $pc $opcode $data_R $data_W $done]
    puts [format "data_addr=%d data_out=0x%04X" $data_addr $data_out]
    puts [format "instruction_in_snap=0x%05X snapshot_counter=%d" $instr $sample]
    puts [format "H0_snap=0x%04X H1_snap=0x%04X H2_snap=0x%04X H3_snap=0x%04X" $h0 $h1 $h2 $h3]
    puts [format "fifo_count=%d fifo_overflow=%d" $fifo_count $fifo_overflow]
}

proc read_cpu_debug {base_addr} {
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        puts "No JTAG Avalon master found. Check programming and cable."
        return
    }

    set m [lindex $masters 0]
    open_service master $m

    set regs [master_read_32 $m $base_addr 9]
    close_service master $m

    set parsed [parse_cpu_debug $regs]
    print_cpu_debug $parsed
}

proc pop_cpu_debug {base_addr} {
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        puts "No JTAG Avalon master found. Check programming and cable."
        return
    }

    set m [lindex $masters 0]
    open_service master $m
    set pop_addr [expr {$base_addr + 36}]
    master_write_32 $m $pop_addr 1
    close_service master $m
}

# Poll and print on each new instruction sample (sample_counter change)
# poll_ms: delay between reads (ms)
# max_samples: 0 for unlimited
proc poll_cpu_debug {base_addr {poll_ms 10} {max_samples 0} {max_polls 0}} {
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        puts "No JTAG Avalon master found. Check programming and cable."
        return
    }

    set m [lindex $masters 0]
    open_service master $m

    set samples 0

    set polls 0
    set pop_addr [expr {$base_addr + 36}]

    while {1} {
        set regs [master_read_32 $m $base_addr 9]
        set parsed [parse_cpu_debug $regs]

        lassign $parsed reg0 reg1 reg2 reg3 pc opcode data_R data_W done \
                        data_addr data_out instr sample h0 h1 h2 h3 \
                        fifo_count fifo_overflow

        if {$fifo_count > 0} {
            print_cpu_debug $parsed
            master_write_32 $m $pop_addr 1

            if {$max_samples > 0} {
                incr samples
                if {$samples >= $max_samples} {
                    break
                }
            }
        }

        if {$max_polls > 0} {
            incr polls
            if {$polls >= $max_polls} {
                puts "Stopping poll: max_polls reached without further snapshots."
                break
            }
        }

        if {$done && $fifo_count == 0} {
            break
        }

        if {$poll_ms > 0} {
            after $poll_ms
        }
    }

    close_service master $m
}

# Default base address used in the system
read_cpu_debug 0x00000000
