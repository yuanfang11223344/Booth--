`timescale 1ns/1ps
// Classic radix-2 Booth multiplier. WIDTH >= 2. Signed two's-complement.
// One Booth decision and one arithmetic right shift per busy clock.
module booth_radix2_iter #(
    parameter WIDTH = 8
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,
    input  wire signed [WIDTH-1:0]  multiplicand,
    input  wire signed [WIDTH-1:0]  multiplier,
    output reg  signed [2*WIDTH-1:0] product,
    output reg                      busy,
    output reg                      done
);
    localparam COUNT_WIDTH = $clog2(WIDTH + 1);
    localparam integer LAST = WIDTH-1;
    localparam [COUNT_WIDTH-1:0] LAST_COUNT = LAST[COUNT_WIDTH-1:0];
    reg signed [WIDTH:0] a_reg;
    reg [WIDTH-1:0] q_reg;
    reg q_minus;
    reg signed [WIDTH:0] m_reg;
    reg [COUNT_WIDTH-1:0] count;

    reg signed [WIDTH:0] a_after_add;
    reg signed [2*WIDTH+1:0] shifted;
    always @* begin
        a_after_add = a_reg;
        case ({q_reg[0], q_minus})
            2'b01: a_after_add = a_reg + m_reg;
            2'b10: a_after_add = a_reg - m_reg;
            default: ;
        endcase
        // The explicit $signed is essential: concatenations are unsigned.
        shifted = $signed({a_after_add, q_reg, q_minus}) >>> 1;
    end

    always @(posedge clk) begin
        if (rst) begin
            a_reg <= 0;
            q_reg <= 0;
            q_minus <= 0;
            m_reg <= 0;
            count <= 0;
            product <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                a_reg <= 0;
                q_reg <= multiplier;
                q_minus <= 0;
                m_reg <= {multiplicand[WIDTH-1], multiplicand};
                count <= 0;
                busy <= 1;
            end else if (busy) begin
                a_reg <= shifted[2*WIDTH+1:WIDTH+1];
                q_reg <= shifted[WIDTH:1];
                q_minus <= shifted[0];
                count <= count + 1'b1;
                if (count == LAST_COUNT) begin
                    // The guard bit a_reg[WIDTH] is discarded at the output.
                    product <= shifted[2*WIDTH:1];
                    busy <= 0;
                    done <= 1;
                end
            end
        end
    end
endmodule
