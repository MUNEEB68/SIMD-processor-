module cpu_debug_tap (
    // clock & reset
    input  clk,
    input  reset_n,

    // CPU observation signals
    input  [17:0] instruction_in,
    input  [9:0]  instruction_address,
    input  [9:0]  data_address,
    input  [15:0] data_out,
    input         data_R,
    input         data_W,
    input         done,
    input  [15:0] h0,
    input  [15:0] h1,
    input  [15:0] h2,
    input  [15:0] h3,

    // Avalon-MM slave interface (s0)
    input  [3:0]  s0_address,
    input         s0_read,
    input         s0_write,
    input  [3:0]  s0_byteenable,
    input  [7:0]  s0_burstcount,
    input         s0_beginbursttransfer,
    input  [31:0] s0_writedata,
    output reg [31:0] s0_readdata,
    output reg       s0_readdatavalid,
    output            s0_waitrequest
);

    // opcode extraction
    wire [5:0] opcode = instruction_in[17:12];

    // small sample counter to show instruction progress
    reg [15:0] sample_counter;
    reg [9:0]  last_instruction_address;

    // simple implementation: zero waitrequest (no backpressure)
    assign s0_waitrequest = 1'b0;

    // detect instruction address changes to increment sample counter
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            last_instruction_address <= 10'd0;
            sample_counter <= 16'd0;
        end else begin
            if (instruction_address != last_instruction_address) begin
                last_instruction_address <= instruction_address;
                sample_counter <= sample_counter + 16'd1;
            end
        end
    end

    // synchronous read: provide readdata on the cycle after s0_read is asserted
    reg read_pending;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            s0_readdata      <= 32'd0;
            s0_readdatavalid <= 1'b0;
            read_pending     <= 1'b0;
        end else begin
            s0_readdatavalid <= 1'b0; // default
            if (s0_read && !read_pending) begin
                // capture read request and prepare data next cycle
                read_pending <= 1'b1;
            end else if (read_pending) begin
                // on the cycle after the read request, present data and valid
                case (s0_address)
                    4'd0: s0_readdata <= {10'd0, done, data_W, data_R, opcode, instruction_address};
                    4'd1: s0_readdata <= {16'd0, data_out, data_address};
                    4'd2: s0_readdata <= {14'd0, instruction_in};
                    4'd3: s0_readdata <= {16'd0, sample_counter};
                    4'd4: s0_readdata <= {16'd0, h0};
                    4'd5: s0_readdata <= {16'd0, h1};
                    4'd6: s0_readdata <= {16'd0, h2};
                    4'd7: s0_readdata <= {16'd0, h3};
                    default: s0_readdata <= 32'd0;
                endcase
                s0_readdatavalid <= 1'b1;
                read_pending <= 1'b0;
            end
        end
    end

endmodule