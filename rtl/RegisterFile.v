module RegisterFile(
    input clk,
    input we,
    input [1:0] addr,
    input [15:0] din,
    output [15:0] dout,
    output [15:0] r0,
    output [15:0] r1,
    output [15:0] r2,
    output [15:0] r3
);

reg [15:0] regs [0:3];

assign dout = regs[addr];
assign r0 = regs[0];
assign r1 = regs[1];
assign r2 = regs[2];
assign r3 = regs[3];

always @(posedge clk) begin
    if(we)
        regs[addr] <= din;
end

endmodule