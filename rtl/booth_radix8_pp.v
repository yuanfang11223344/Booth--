`timescale 1ns/1ps
// Shared radix-8 modified Booth partial-product generator.
module booth_radix8_pp #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire [((WIDTH+2)/3)*2*WIDTH-1:0] rows
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+2)/3;
    localparam PAD = (3 - (WIDTH % 3)) % 3;
    wire [WIDTH+PAD:0] y_ext = {{PAD{multiplier[WIDTH-1]}}, multiplier, 1'b0};
    wire signed [PW-1:0] m_ext = {{WIDTH{multiplicand[WIDTH-1]}}, multiplicand};
    wire signed [PW-1:0] triple_m = (m_ext <<< 1) + m_ext;

    function signed [PW-1:0] decode;
        input [3:0] code;
        input signed [PW-1:0] m;
        input signed [PW-1:0] triple;
        begin
            case (code)
                4'b0000, 4'b1111: decode = 0;
                4'b0001, 4'b0010: decode = m;
                4'b0011, 4'b0100: decode = m <<< 1;
                4'b0101, 4'b0110: decode = triple;
                4'b0111: decode = m <<< 2;
                4'b1000: decode = -(m <<< 2);
                4'b1001, 4'b1010: decode = -triple;
                4'b1011, 4'b1100: decode = -(m <<< 1);
                4'b1101, 4'b1110: decode = -m;
                default: decode = 0;
            endcase
        end
    endfunction

    genvar k;
    generate for (k = 0; k < ROWS; k = k + 1) begin: g_row
        wire [3:0] code = y_ext[3*k+3 -: 4];
        wire signed [PW-1:0] selected = decode(code, m_ext, triple_m);
        assign rows[k*PW +: PW] = selected <<< (3*k);
    end endgenerate
endmodule
