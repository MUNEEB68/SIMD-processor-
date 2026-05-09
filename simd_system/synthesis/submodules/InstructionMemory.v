module InstructionMemory(
    input clk,
    input [9:0] addr,
    output [17:0] instruction
);

reg [17:0] mem [0:1023];

initial begin
    $readmemb("mem/program.mem", mem);
end

assign instruction = mem[addr];

endmodule