module cpu_signal_fanout(
    input clk,
    input [9:0]  cpu_instruction_address,
    input [9:0]  cpu_data_address,
    input [15:0] cpu_data_out,
    input        cpu_data_R,
    input        cpu_data_W,
    input        cpu_done,
    output [9:0]  instr_mem_addr,
    output [9:0]  data_mem_addr,
    output [15:0] data_mem_data_in,
    output        data_mem_read_en,
    output        data_mem_write_en,
    output [9:0]  dbg_instruction_address,
    output [9:0]  dbg_data_address,
    output [15:0] dbg_data_out,
    output        dbg_data_R,
    output        dbg_data_W,
    output        dbg_done
);

    assign instr_mem_addr         = cpu_instruction_address;
    assign data_mem_addr          = cpu_data_address;
    assign data_mem_data_in       = cpu_data_out;
    assign data_mem_read_en       = cpu_data_R;
    assign data_mem_write_en      = cpu_data_W;
    assign dbg_instruction_address = cpu_instruction_address;
    assign dbg_data_address       = cpu_data_address;
    assign dbg_data_out           = cpu_data_out;
    assign dbg_data_R             = cpu_data_R;
    assign dbg_data_W             = cpu_data_W;
    assign dbg_done               = cpu_done;

endmodule
