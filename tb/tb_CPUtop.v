`timescale 1ns/1ps

module tb_CPUtop;

reg clk;
reg rst;

reg [17:0] instruction_mem [0:255];
reg [15:0] data_mem [0:255];

wire [15:0] data_out;
wire [9:0] instruction_address;
wire [9:0] data_address;
wire data_R;
wire data_W;
wire done;

wire [17:0] instruction_in;

assign instruction_in = instruction_mem[instruction_address];

CPUtop uut(
    .clk(clk),
    .rst(rst),
    .instruction_in(instruction_in),
    .data_in(data_mem[data_address]),
    .data_out(data_out),
    .instruction_address(instruction_address),
    .data_address(data_address),
    .data_R(data_R),
    .data_W(data_W),
    .done(done)
);

// CLOCK
always #5 clk = ~clk;

// MEMORY WRITE BACK
always @(posedge clk) begin
    if(data_W)
        data_mem[data_address] <= data_out;
end

// Per-cycle snapshot
always @(posedge clk) begin
    if (!rst) begin
        cycle <= cycle + 1;
        $strobe("C=%0d PC=%0d state=%0d instr=%b | H0=%0d H1=%0d H2=%0d H3=%0d",
                cycle,
                instruction_address,
                uut.current_state,
                instruction_in,
                uut.H[0], uut.H[1], uut.H[2], uut.H[3]);
    end
end

// Per-instruction snapshot (post-WB)
always @(posedge clk) begin
    if (!rst && (uut.current_state == 3'd5)) begin
        $strobe("INST_DONE PC=%0d instr=%b | H0=%0d H1=%0d H2=%0d H3=%0d",
                instruction_address,
                instruction_in,
                uut.H[0], uut.H[1], uut.H[2], uut.H[3]);
    end
end

integer i;
integer cycle;

initial begin

    clk = 0;
    rst = 1;
    cycle = 0;

    // init memory
    for(i=0;i<256;i=i+1) begin
        instruction_mem[i] = 0;
        data_mem[i] = 0;
    end

    // LOAD PROGRAM (same as program.mem)
    instruction_mem[0] = 18'b101100000000010101;
    instruction_mem[1] = 18'b101100010000101010;
    instruction_mem[2] = 18'b000000000100010000;
    instruction_mem[3] = 18'b001100000100010000;
    instruction_mem[4] = 18'b010101000000000000;
    instruction_mem[5] = 18'b1010010000010100;
    instruction_mem[6] = 18'b1001101000010100;
    instruction_mem[7] = 18'b111111000000000000;

    #20;
    rst = 0;

    wait(done);

    $display("\n==== FINAL STATE ====");
    $display("H0 = %d", uut.H[0]);
    $display("H1 = %d", uut.H[1]);
    $display("H2 = %d", uut.H[2]);
    $display("MEM[20] = %d", data_mem[20]);

    $stop;
end

endmodule