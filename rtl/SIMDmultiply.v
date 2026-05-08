module SIMDmultiply(
    input [15:0] mulinputa,
    input [15:0] mulinputb,
    input H,
    input O,
    input Q,
    output reg [15:0] muloutput
);

always @(*) begin

    if(H)
        muloutput = mulinputa * mulinputb;

    else if(O) begin
        muloutput[15:8] = mulinputa[15:8] * mulinputb[15:8];
        muloutput[7:0]  = mulinputa[7:0]  * mulinputb[7:0];
    end

    else if(Q) begin
        muloutput[15:12] = mulinputa[15:12] * mulinputb[15:12];
        muloutput[11:8]  = mulinputa[11:8]  * mulinputb[11:8];
        muloutput[7:4]   = mulinputa[7:4]   * mulinputb[7:4];
        muloutput[3:0]   = mulinputa[3:0]   * mulinputb[3:0];
    end

end

endmodule