`timescale 1ns/1ps
// Recursive 3:2 compression of ROWS operands into two WIDTH-bit vectors.
// This is a row-wise CSA tree, not a separately optimized Wallace/Dadda tree.
module csa_reduce #(
    parameter WIDTH = 16,
    parameter ROWS = 4
) (
    input  wire [ROWS*WIDTH-1:0] operands,
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] carry
);
    generate if (ROWS == 1) begin: g_one
        assign sum = operands[0 +: WIDTH];
        assign carry = 0;
    end else if (ROWS == 2) begin: g_two
        assign sum = operands[0 +: WIDTH];
        assign carry = operands[WIDTH +: WIDTH];
    end else begin: g_many
        localparam GROUPS = ROWS/3;
        localparam REST = ROWS%3;
        localparam NEXT_ROWS = 2*GROUPS + REST;
        wire [NEXT_ROWS*WIDTH-1:0] next_operands;
        genvar g;
        for (g = 0; g < GROUPS; g = g + 1) begin: g_compress
            wire [WIDTH-1:0] a = operands[(3*g)*WIDTH +: WIDTH];
            wire [WIDTH-1:0] b = operands[(3*g+1)*WIDTH +: WIDTH];
            wire [WIDTH-1:0] c = operands[(3*g+2)*WIDTH +: WIDTH];
            assign next_operands[(2*g)*WIDTH +: WIDTH] = a ^ b ^ c;
            assign next_operands[(2*g+1)*WIDTH +: WIDTH] =
                ((a & b) | (a & c) | (b & c)) << 1;
        end
        for (g = 0; g < REST; g = g + 1) begin: g_rest
            assign next_operands[(2*GROUPS+g)*WIDTH +: WIDTH] =
                operands[(3*GROUPS+g)*WIDTH +: WIDTH];
        end
        csa_reduce #(.WIDTH(WIDTH), .ROWS(NEXT_ROWS)) next_stage(
            .operands(next_operands), .sum(sum), .carry(carry));
    end endgenerate
endmodule
