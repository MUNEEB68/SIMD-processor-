module SIMDshifter(
    input [15:0] shiftinput,
    input H,
    input O,
    input Q,
    input left,
    input right,
    output reg [15:0] shiftoutput
);

always @(*) begin

    if(left)
        shiftoutput = shiftinput << 1;

    else if(right)
        shiftoutput = shiftinput >> 1;

    else
        shiftoutput = shiftinput;

end

endmodule