module DataMemory(
    input clk,
    input we,
    input re,
    input [9:0] addr,
    input [15:0] din,
    output reg [15:0] dout
);

reg [15:0] mem [0:1023];

always @(posedge clk) begin

    if(we)
        mem[addr] <= din;

    if(re)
        dout <= mem[addr];

end

endmodule