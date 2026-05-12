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
    reg [17:0] prev_instruction_in;
    reg        prev_data_R;
    reg        prev_data_W;
    reg        prev_done;
    reg [9:0]  prev_data_address;
    reg [15:0] prev_data_out;

    // pending metadata captured on instruction completion (PC change)
    reg        capture_pending;
    reg [15:0] pending_sample;
    reg [9:0]  pending_pc;
    reg [5:0]  pending_opcode;
    reg        pending_data_R;
    reg        pending_data_W;
    reg        pending_done;
    reg [9:0]  pending_data_address;
    reg [15:0] pending_data_out;
    reg [17:0] pending_instruction_in;

    // FIFO for post-instruction snapshots
    localparam FIFO_DEPTH = 16;
    localparam FIFO_PTR_W = 4;

    reg [31:0] fifo_word0 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word1 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word2 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word3 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word4 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word5 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word6 [0:FIFO_DEPTH-1];
    reg [31:0] fifo_word7 [0:FIFO_DEPTH-1];

    reg [FIFO_PTR_W-1:0] fifo_wr_ptr;
    reg [FIFO_PTR_W-1:0] fifo_rd_ptr;
    reg [FIFO_PTR_W:0]   fifo_count;
    reg                  fifo_overflow;
    reg                  done_captured;

    // simple implementation: zero waitrequest (no backpressure)
    assign s0_waitrequest = 1'b0;

    // detect instruction address changes to increment sample counter
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            last_instruction_address <= 10'd0;
            sample_counter <= 16'd0;
            prev_instruction_in <= 18'd0;
            prev_data_R <= 1'b0;
            prev_data_W <= 1'b0;
            prev_done <= 1'b0;
            prev_data_address <= 10'd0;
            prev_data_out <= 16'd0;
            capture_pending <= 1'b0;
            pending_sample <= 16'd0;
            pending_pc <= 10'd0;
            pending_opcode <= 6'd0;
            pending_data_R <= 1'b0;
            pending_data_W <= 1'b0;
            pending_done <= 1'b0;
            pending_data_address <= 10'd0;
            pending_data_out <= 16'd0;
            pending_instruction_in <= 18'd0;
            fifo_wr_ptr <= {FIFO_PTR_W{1'b0}};
            fifo_rd_ptr <= {FIFO_PTR_W{1'b0}};
            fifo_count <= {FIFO_PTR_W+1{1'b0}};
            fifo_overflow <= 1'b0;
            done_captured <= 1'b0;
        end else begin
            if (done && !done_captured && !capture_pending) begin
                pending_pc <= instruction_address;
                pending_opcode <= opcode;
                pending_data_R <= data_R;
                pending_data_W <= data_W;
                pending_done <= 1'b1;
                pending_data_address <= data_address;
                pending_data_out <= data_out;
                pending_instruction_in <= instruction_in;
                pending_sample <= sample_counter;
                capture_pending <= 1'b1;
                done_captured <= 1'b1;
            end
            if (instruction_address != last_instruction_address) begin
                pending_pc <= last_instruction_address;
                pending_opcode <= prev_instruction_in[17:12];
                pending_data_R <= prev_data_R;
                pending_data_W <= prev_data_W;
                pending_done <= prev_done;
                pending_data_address <= prev_data_address;
                pending_data_out <= prev_data_out;
                pending_instruction_in <= prev_instruction_in;
                last_instruction_address <= instruction_address;
                sample_counter <= sample_counter + 16'd1;
                pending_sample <= sample_counter + 16'd1;
                capture_pending <= 1'b1;
            end

            // FIFO push/pop
            if (capture_pending) begin
                if ((fifo_count < FIFO_DEPTH) || (s0_write && (s0_address == 4'd9) && s0_writedata[0] && (fifo_count != 0))) begin
                    fifo_word0[fifo_wr_ptr] <= {10'd0, pending_done, pending_data_W, pending_data_R, pending_opcode, pending_pc};
                    fifo_word1[fifo_wr_ptr] <= {16'd0, pending_data_out, pending_data_address};
                    fifo_word2[fifo_wr_ptr] <= {14'd0, pending_instruction_in};
                    fifo_word3[fifo_wr_ptr] <= {16'd0, pending_sample};
                    fifo_word4[fifo_wr_ptr] <= {16'd0, h0};
                    fifo_word5[fifo_wr_ptr] <= {16'd0, h1};
                    fifo_word6[fifo_wr_ptr] <= {16'd0, h2};
                    fifo_word7[fifo_wr_ptr] <= {16'd0, h3};
                    fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
                end else begin
                    fifo_overflow <= 1'b1;
                end
                capture_pending <= 1'b0;
            end

            if (s0_write && (s0_address == 4'd9) && s0_writedata[0] && (fifo_count != 0)) begin
                fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
            end

            if (capture_pending && !(s0_write && (s0_address == 4'd9) && s0_writedata[0] && (fifo_count != 0))) begin
                if (fifo_count < FIFO_DEPTH) fifo_count <= fifo_count + 1'b1;
            end else if (!capture_pending && (s0_write && (s0_address == 4'd9) && s0_writedata[0]) && (fifo_count != 0)) begin
                fifo_count <= fifo_count - 1'b1;
            end

            if (s0_write && (s0_address == 4'd8) && s0_writedata[0]) begin
                fifo_overflow <= 1'b0;
            end

            prev_instruction_in <= instruction_in;
            prev_data_R <= data_R;
            prev_data_W <= data_W;
            prev_done <= done;
            prev_data_address <= data_address;
            prev_data_out <= data_out;
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
                    4'd0: s0_readdata <= fifo_word0[fifo_rd_ptr];
                    4'd1: s0_readdata <= fifo_word1[fifo_rd_ptr];
                    4'd2: s0_readdata <= fifo_word2[fifo_rd_ptr];
                    4'd3: s0_readdata <= fifo_word3[fifo_rd_ptr];
                    4'd4: s0_readdata <= fifo_word4[fifo_rd_ptr];
                    4'd5: s0_readdata <= fifo_word5[fifo_rd_ptr];
                    4'd6: s0_readdata <= fifo_word6[fifo_rd_ptr];
                    4'd7: s0_readdata <= fifo_word7[fifo_rd_ptr];
                    4'd8: s0_readdata <= {15'd0, fifo_overflow, fifo_count};
                    default: s0_readdata <= 32'd0;
                endcase
                s0_readdatavalid <= 1'b1;
                read_pending <= 1'b0;
            end
        end
    end

endmodule