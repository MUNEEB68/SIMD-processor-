module CPUtop(
    input clk, rst, //clock and reset
    input  [17:0] instruction_in, // instruction from instruction memory (18 bits: 6 opcode + 12 for reg/immediate)
    input  [15:0] data_in, //data in from data memory
    output [15:0] data_out, //data out to data memory
    output [9:0]  instruction_address, //PC to instruction memory (10 bits for 1024 instructions)
    output [9:0]  data_address, //address to data memory (10 bits for 1024 words)
    output data_R, data_W, done, //enable signal for write,read,done
    output [15:0] h0,
    output [15:0] h1,
    output [15:0] h2,
    output [15:0] h3
);

wire [5:0] opcode = instruction_in[17:12]; //opcode extraction

// FSM states
parameter STATE_IDLE = 3'd0; 
parameter STATE_IF   = 3'd1;
parameter STATE_ID   = 3'd2;
parameter STATE_EX   = 3'd3;
parameter STATE_MEM  = 3'd4;
parameter STATE_WB   = 3'd5;
parameter STATE_HALT = 3'd6;

reg [2:0] current_state;
reg [9:0] PC, next_PC;

// SIMD register banks
reg [15:0] H[0:3];       // 4 regs, 2×16-bit lanes
reg [15:0] Oset[0:2];    // 3 regs, 4×8-bit lanes
reg [15:0] Qset[0:2];    // 3 regs, 8×4-bit lanes
reg [9:0]  LC;           // loop counter
reg [9:0]  im_reg;       // immediate value

// act as control wires from control unit (set in ID, used in EX+WB)
reg CMD_addition, CMD_substruction, CMD_multiplication;
reg CMD_mul_accumulation;
reg CMD_logic_shift_left, CMD_logic_shift_right;
reg CMD_and, CMD_or, CMD_not;
reg CMD_load, CMD_store, CMD_set;
reg CMD_loopjump, CMD_setloop;

// mode flags
reg Hreg1, Hreg2, Hreg3, Him;
reg Oreg1, Oreg2, Oreg3, Oim;
reg Qreg1, Qreg2, Qreg3, Qim;

// register indices
reg [1:0] R0, R1, R2, R3;

// result registers after execute stage (EX writes, WB reads)
reg [15:0] result_reg_add, result_reg_sub, result_reg_mul;
reg [15:0] result_reg_mac, result_reg_Lshift, result_reg_Rshift;
reg [15:0] result_reg_and, result_reg_or, result_reg_not;
reg [15:0] result_reg_set;

// memory signals(handle load/store etc)
reg [9:0]  current_data_address; //memory adress i want to access in current instruction
reg        rdata_en, wdata_en; //enable signals 
reg [15:0] data_out_reg; //data to write to memory, set in EX, used in MEM

// output assignments
assign data_out     = data_out_reg;
assign data_R       = rdata_en;
assign data_W       = wdata_en;
assign data_address = current_data_address;
assign instruction_address = PC;
assign done = (current_state == STATE_HALT);
assign h0 = H[0];
assign h1 = H[1];
assign h2 = H[2];
assign h3 = H[3];

//FSM 
always @(posedge clk) begin
    if (rst) begin
        current_state <= STATE_IDLE;
        PC <= 0;
    end
    else begin
        if (opcode == 63)
            current_state <= STATE_HALT;
        else case (current_state)
            STATE_IDLE: current_state <= STATE_IF;
            STATE_IF: begin
                // print register values here like repo does
                $display("=== new instruction ===");
                $display("H[0]=%b H[1]=%b", H[0], H[1]);
                $display("H[2]=%b H[3]=%b", H[2], H[3]);
                current_state <= STATE_ID;
            end
            STATE_ID:  current_state <= STATE_EX;
            STATE_EX:  current_state <= STATE_MEM;
            STATE_MEM: current_state <= STATE_WB;
            STATE_WB: begin
                current_state <= STATE_IF;
                PC <= next_PC;   // advance PC after writeback
            end
        endcase
    end
end
// Fetch and Decode logic
always @(posedge clk) begin
    if (rst || current_state == STATE_IDLE || current_state == STATE_IF) begin
        // clear all flags every new instruction
        CMD_addition<=0; CMD_substruction<=0; CMD_multiplication<=0;
        CMD_mul_accumulation<=0; CMD_logic_shift_left<=0; CMD_logic_shift_right<=0;
        CMD_and<=0; CMD_or<=0; CMD_not<=0;
        CMD_load<=0; CMD_store<=0; CMD_set<=0;
        CMD_loopjump<=0; CMD_setloop<=0;
        Hreg1<=0; Hreg2<=0; Hreg3<=0; Him<=0;
        Oreg1<=0; Oreg2<=0; Oreg3<=0; Oim<=0;
        Qreg1<=0; Qreg2<=0; Qreg3<=0; Qim<=0;
        R0<=0; R1<=0; R2<=0; R3<=0; im_reg<=0;
    end
    else if (current_state == STATE_ID) begin
        
        // WHAT operation
        CMD_addition        <= (opcode<=5);
        CMD_substruction    <= (opcode>=6)  && (opcode<=11);
        CMD_multiplication  <= (opcode>=12) && (opcode<=17);
        CMD_mul_accumulation<= (opcode>=18) && (opcode<=20);
        CMD_logic_shift_left<= (opcode>=21) && (opcode<=23);
        CMD_logic_shift_right<=(opcode>=24) && (opcode<=26);
        CMD_and             <= (opcode>=27) && (opcode<=29);
        CMD_or              <= (opcode>=30) && (opcode<=32);
        CMD_not             <= (opcode>=33) && (opcode<=35);
        CMD_loopjump        <= (opcode==36);
        CMD_setloop         <= (opcode==37);
        CMD_load            <= (opcode>=38) && (opcode<=40);
        CMD_store           <= (opcode>=41) && (opcode<=43);
        CMD_set             <= (opcode>=44) && (opcode<=46);
        
        // WHICH mode (H/O/Q) + WHICH format (reg-reg or reg-imm)
        Hreg1 <= (opcode==3)||(opcode==9)||(opcode==15)||
                 (opcode==21)||(opcode==24)||(opcode==33)||
                 (opcode==38)||(opcode==41)||(opcode==44);
        Hreg2 <= (opcode==0)||(opcode==6)||(opcode==12)||
                 (opcode==27)||(opcode==30);
        Hreg3 <= (opcode==18);
        Him   <= (opcode==3)||(opcode==9)||(opcode==15)||
                 (opcode==38)||(opcode==41)||(opcode==44);

        Oreg1 <= (opcode==4)||(opcode==10)||(opcode==16)||
                 (opcode==22)||(opcode==25)||(opcode==34)||
                 (opcode==39)||(opcode==42)||(opcode==45);
        Oreg2 <= (opcode==1)||(opcode==7)||(opcode==13)||
                 (opcode==28)||(opcode==31);
        Oreg3 <= (opcode==19);
        Oim   <= (opcode==4)||(opcode==10)||(opcode==16)||
                 (opcode==39)||(opcode==42)||(opcode==45);

        Qreg1 <= (opcode==5)||(opcode==11)||(opcode==17)||
                 (opcode==23)||(opcode==26)||(opcode==35)||
                 (opcode==40)||(opcode==43)||(opcode==46);
        Qreg2 <= (opcode==2)||(opcode==8)||(opcode==14)||
                 (opcode==29)||(opcode==32);
        Qreg3 <= (opcode==20);
        Qim   <= (opcode==5)||(opcode==11)||(opcode==17)||
                 (opcode==40)||(opcode==43)||(opcode==46);

        // extract fields from instruction 
        //deciedes source/destination registers and immediate value based on instruction format
        R0     <= instruction_in[11:10]; //register field 0
        R1     <= instruction_in[5:4]; //register field 1   
        R2     <= instruction_in[3:2]; //register field 2
        R3     <= instruction_in[1:0]; //register field 3
        im_reg <= instruction_in[9:0]; //immediate value
        
        $display("PC:%0d instruction=%b", PC, instruction_in);
    end
end

//choose inputs for ALU based on instruction type and mode

// input A — picks from H, O, or Q register
wire [15:0] comp_input_A =
    Hreg1 ? H[R0] :
    (Hreg2|Hreg3) ? H[R2] :
    Oreg1 ? Oset[R0] :
    (Oreg2|Oreg3) ? Oset[R2] :
    Qreg1 ? Qset[R0] : Qset[R2];

// input B — picks register or immediate
wire [15:0] comp_input_B =
    Hreg1 ? im_reg :
    (Hreg2|Hreg3) ? H[R3] :
    Oreg1 ? {im_reg[7:0], im_reg[7:0]} :
    (Oreg2|Oreg3) ? Oset[R3] :
    Qreg1 ? {im_reg[3:0],im_reg[3:0],im_reg[3:0],im_reg[3:0]} :
    Qset[R3];

// MAC special inputs
wire [15:0] MAC_input_A = Hreg3?H[R1]:(Oreg3?Oset[R1]:Qset[R1]);

wire [15:0] Add_output_Cout, Mul_output_Cout;

// instantiate Person B's modules
SIMDadd Add(
    .A(CMD_mul_accumulation ? MAC_input_A : comp_input_A),
    .B(CMD_mul_accumulation ? Mul_output_Cout : comp_input_B),
    .H(Hreg1|Hreg2|Hreg3),
    .O(Oreg1|Oreg2|Oreg3),
    .Q(Qreg1|Qreg2|Qreg3),
    .sub(CMD_substruction),
    .Cout(Add_output_Cout)
);

wire [15:0] shiftinput = Hreg1?H[R3]:(Oreg1?Oset[R3]:Qset[R3]);
wire [15:0] shiftoutput;

SIMDshifter shift(
    .shiftinput(shiftinput),
    .H(Hreg1), .O(Oreg1), .Q(Qreg1),
    .left(CMD_logic_shift_left),
    .shiftoutput(shiftoutput)
);

SIMDmultiply Mul(
    .mulinputa(comp_input_A),
    .mulinputb(comp_input_B),
    .H(Hreg1|Hreg2|Hreg3),
    .O(Oreg1|Oreg2|Oreg3),
    .Q(Qreg1|Qreg2|Qreg3),
    .muloutput(Mul_output_Cout)
);


always @(posedge clk) begin
    if (rst || current_state==STATE_IDLE || current_state==STATE_IF) begin
        result_reg_add<=0; result_reg_sub<=0; result_reg_mul<=0;
        result_reg_mac<=0; result_reg_Lshift<=0; result_reg_Rshift<=0;
        result_reg_and<=0; result_reg_or<=0; result_reg_not<=0;
        result_reg_set<=0;
        rdata_en<=0; wdata_en<=0; current_data_address<=0;
        if(rst) next_PC<=0;
    end
    else if (current_state == STATE_EX) begin
        if      (CMD_addition)      result_reg_add    <= Add_output_Cout;
        else if (CMD_substruction)  result_reg_sub    <= Add_output_Cout;
        else if (CMD_multiplication)result_reg_mul    <= Mul_output_Cout;
        else if (CMD_mul_accumulation) result_reg_mac <= Add_output_Cout;
        else if (CMD_logic_shift_left) result_reg_Lshift <= shiftoutput;
        else if (CMD_logic_shift_right)result_reg_Rshift <= shiftoutput;
        else if (CMD_and) begin
            if      (Hreg2) result_reg_and <= H[R2]    & H[R3];
            else if (Oreg2) result_reg_and <= Oset[R2] & Oset[R3];
            else if (Qreg2) result_reg_and <= Qset[R2] & Qset[R3];
        end
        else if (CMD_or) begin
            if      (Hreg2) result_reg_or <= H[R2]    | H[R3];
            else if (Oreg2) result_reg_or <= Oset[R2] | Oset[R3];
            else if (Qreg2) result_reg_or <= Qset[R2] | Qset[R3];
        end
        else if (CMD_not) begin
            if      (Hreg1) result_reg_not <= ~H[R3];
            else if (Oreg1) result_reg_not <= ~Oset[R3];
            else if (Qreg1) result_reg_not <= ~Qset[R3];
        end
        else if (CMD_set) begin
            if      (Hreg1) result_reg_set <= im_reg;
            else if (Oreg1) result_reg_set <= {im_reg[7:0], im_reg[7:0]};
            else if (Qreg1) result_reg_set <= {im_reg[3:0],im_reg[3:0],
                                               im_reg[3:0],im_reg[3:0]};
        end

        // PC always advances
        if (CMD_loopjump) begin
            if (LC != 0) begin next_PC<=im_reg; LC<=LC-1; end
            else          next_PC <= next_PC + 1;
        end
        else next_PC <= next_PC + 1;

        if (CMD_setloop) LC <= im_reg;
    end
end


always @(posedge clk) begin
    if (current_state == STATE_WB) begin
        if (CMD_addition) begin
            if      (Hreg2) H[R2]    <= result_reg_add;
            else if (Oreg2) Oset[R2] <= result_reg_add;
            else if (Qreg2) Qset[R2] <= result_reg_add;
            else if (Him)   H[R0]    <= result_reg_add;
            else if (Oim)   Oset[R0] <= result_reg_add;
            else if (Qim)   Qset[R0] <= result_reg_add;
        end
        else if (CMD_substruction) begin
            if      (Hreg2) H[R2]    <= result_reg_sub;
            else if (Oreg2) Oset[R2] <= result_reg_sub;
            else if (Qreg2) Qset[R2] <= result_reg_sub;
            else if (Him)   H[R0]    <= result_reg_sub;
            else if (Oim)   Oset[R0] <= result_reg_sub;
            else if (Qim)   Qset[R0] <= result_reg_sub;
        end
        else if (CMD_multiplication) begin
            if      (Hreg2) H[R2]    <= result_reg_mul;
            else if (Oreg2) Oset[R2] <= result_reg_mul;
            else if (Qreg2) Qset[R2] <= result_reg_mul;
            else if (Him)   H[R0]    <= result_reg_mul;
            else if (Oim)   Oset[R0] <= result_reg_mul;
            else if (Qim)   Qset[R0] <= result_reg_mul;
        end
        else if (CMD_mul_accumulation) begin
            if      (Hreg3) H[R1]    <= result_reg_mac;
            else if (Oreg3) Oset[R1] <= result_reg_mac;
            else if (Qreg3) Qset[R1] <= result_reg_mac;
        end
        else if (CMD_logic_shift_left) begin
            if      (Hreg1) H[R3]    <= result_reg_Lshift;
            else if (Oreg1) Oset[R3] <= result_reg_Lshift;
            else if (Qreg1) Qset[R3] <= result_reg_Lshift;
        end
        else if (CMD_logic_shift_right) begin
            if      (Hreg1) H[R3]    <= result_reg_Rshift;
            else if (Oreg1) Oset[R3] <= result_reg_Rshift;
            else if (Qreg1) Qset[R3] <= result_reg_Rshift;
        end
        else if (CMD_and) begin
            if      (Hreg2) H[R2]    <= result_reg_and;
            else if (Oreg2) Oset[R2] <= result_reg_and;
            else if (Qreg2) Qset[R2] <= result_reg_and;
        end
        else if (CMD_or) begin
            if      (Hreg2) H[R2]    <= result_reg_or;
            else if (Oreg2) Oset[R2] <= result_reg_or;
            else if (Qreg2) Qset[R2] <= result_reg_or;
        end
        else if (CMD_not) begin
            if      (Hreg1) H[R3]    <= result_reg_not;
            else if (Oreg1) Oset[R3] <= result_reg_not;
            else if (Qreg1) Qset[R3] <= result_reg_not;
        end
        else if (CMD_set) begin
            if      (Hreg1) H[R0]    <= result_reg_set;
            else if (Oreg1) Oset[R0] <= result_reg_set;
            else if (Qreg1) Qset[R0] <= result_reg_set;
        end
        else if (CMD_load) begin
            if      (Hreg1) H[R0]    <= data_in;
            else if (Oreg1) Oset[R0] <= data_in;
            else if (Qreg1) Qset[R0] <= data_in;
        end
    end
end

endmodule