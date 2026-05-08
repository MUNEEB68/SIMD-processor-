module CPUtop(
    input clk,
    input rst,
    input  [17:0] instruction_in,
    input  [15:0] data_in,
    output reg [15:0] data_out,
    output [9:0] instruction_address,
    output reg [9:0] data_address,
    output reg data_R,
    output reg data_W,
    output done
);

////////////////////////////////////////////////////
// 1. FSM STATES (MUST BE FIRST)
////////////////////////////////////////////////////
parameter STATE_IDLE = 3'd0;
parameter STATE_IF   = 3'd1;
parameter STATE_ID   = 3'd2;
parameter STATE_EX   = 3'd3;
parameter STATE_MEM  = 3'd4;
parameter STATE_WB   = 3'd5;
parameter STATE_HALT = 3'd6;

////////////////////////////////////////////////////
// 2. CORE REGISTERS (BEFORE ANY ASSIGN USE)
////////////////////////////////////////////////////
reg [2:0] state;
reg [9:0] PC;
reg [9:0] next_PC;

assign instruction_address = PC;
assign done = (state == STATE_HALT);

////////////////////////////////////////////////////
// 3. SIMD REG FILE
////////////////////////////////////////////////////
reg [15:0] H[0:3];
reg [15:0] O[0:3];
reg [15:0] Q[0:3];

reg [9:0] LC;
reg [9:0] imm;

reg [1:0] R0,R1,R2,R3;

integer i;

////////////////////////////////////////////////////
// 4. CONTROL SIGNALS
////////////////////////////////////////////////////
reg add, sub, mul;
reg lsl, lsr;
reg load, store, set;
reg loopjmp, setloop;

////////////////////////////////////////////////////
// 5. RESET + FSM
////////////////////////////////////////////////////
always @(posedge clk) begin

    if(rst) begin
        state <= STATE_IDLE;
        PC <= 0;
        next_PC <= 0;
        LC <= 0;

        data_R <= 0;
        data_W <= 0;
        data_out <= 0;
        data_address <= 0;

        for(i=0;i<4;i=i+1) begin
            H[i] <= 0;
            O[i] <= 0;
            Q[i] <= 0;
        end
    end

    else begin
        case(state)

            STATE_IDLE: state <= STATE_IF;

            STATE_IF: state <= STATE_ID;

            STATE_ID: begin
                if(instruction_in[17:12] == 6'b111111)
                    state <= STATE_HALT;
                else
                    state <= STATE_EX;
            end

            STATE_EX: state <= STATE_MEM;

            STATE_MEM: state <= STATE_WB;

            STATE_WB: begin
                state <= STATE_IF;
                PC <= next_PC;
            end

            STATE_HALT: state <= STATE_HALT;

        endcase
    end
end

////////////////////////////////////////////////////
// 6. DECODE
////////////////////////////////////////////////////
always @(posedge clk) begin
    if(state == STATE_ID) begin

        add=0; sub=0; mul=0;
        lsl=0; lsr=0;
        load=0; store=0; set=0;
        loopjmp=0; setloop=0;

        case(instruction_in[17:12])

        0,1,2,3,4,5: add = 1;
        6,7,8,9,10,11: sub = 1;
        12,13,14,15,16,17: mul = 1;

        21,22,23: lsl = 1;
        24,25,26: lsr = 1;

        38,39,40: load = 1;
        41,42,43: store = 1;

        44,45,46: set = 1;

        36: loopjmp = 1;
        37: setloop = 1;

        default: ;

        endcase

        R0 <= instruction_in[11:10];
        R1 <= instruction_in[5:4];
        R2 <= instruction_in[3:2];
        R3 <= instruction_in[1:0];
        imm <= instruction_in[9:0];

    end
end

////////////////////////////////////////////////////
// 7. EXECUTE
////////////////////////////////////////////////////
always @(posedge clk) begin
    if(state == STATE_EX) begin

        if(add)
            H[R0] <= H[R0] + H[R1];

        if(sub)
            H[R0] <= H[R0] - H[R1];

        if(mul)
            H[R0] <= H[R0] * H[R1];

        if(lsl)
            H[R0] <= H[R0] << 1;

        if(lsr)
            H[R0] <= H[R0] >> 1;

        if(set)
            H[R0] <= imm;

        if(load)
            data_address <= imm;

        if(store)
            data_address <= imm;

        if(loopjmp) begin
            if(LC != 0) begin
                next_PC <= imm;
                LC <= LC - 1;
            end else next_PC <= PC + 1;
        end else begin
            next_PC <= PC + 1;
        end

        if(setloop)
            LC <= imm;

    end
end

////////////////////////////////////////////////////
// 8. MEMORY + WB
////////////////////////////////////////////////////
always @(posedge clk) begin
    if(state == STATE_WB) begin

        if(load)
            H[R0] <= data_in;

        if(store) begin
            data_out <= H[R0];
            data_W <= 1;
        end else begin
            data_W <= 0;
        end

        data_R <= load;

    end
end

endmodule