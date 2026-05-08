module SIMDadd(
    input [15:0] A,
    input [15:0] B,
    input H,
    input O,
    input Q,
    input sub,
    output reg [15:0] Cout
);

always @(*) begin

    if(H)
        Cout = sub ? (A - B) : (A + B);

    else if(O) begin
        Cout[15:8] = sub ? (A[15:8]-B[15:8]) : (A[15:8]+B[15:8]);
        Cout[7:0]  = sub ? (A[7:0]-B[7:0])   : (A[7:0]+B[7:0]);
    end

    else if(Q) begin
        Cout[15:12] = sub ? (A[15:12]-B[15:12]) : (A[15:12]+B[15:12]);
        Cout[11:8]  = sub ? (A[11:8]-B[11:8])   : (A[11:8]+B[11:8]);
        Cout[7:4]   = sub ? (A[7:4]-B[7:4])     : (A[7:4]+B[7:4]);
        Cout[3:0]   = sub ? (A[3:0]-B[3:0])     : (A[3:0]+B[3:0]);
    end

end

endmodule