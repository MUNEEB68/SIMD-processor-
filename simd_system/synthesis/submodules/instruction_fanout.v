module instruction_fanout(
    input clk,
    input [17:0] instr_in,
    output [17:0] instr_to_cpu,
    output [17:0] instr_to_dbg
);

    assign instr_to_cpu = instr_in;
    assign instr_to_dbg = instr_in;

endmodule
