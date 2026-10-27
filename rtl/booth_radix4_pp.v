`timescale 1ns/1ps
// Modified Booth recoder and sign-extended shifted partial-product rows.
// rows[k*2*WIDTH +: 2*WIDTH] is digit k times M times 2^(2k).
module booth_radix4_pp #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire [((WIDTH+1)/2)*2*WIDTH-1:0] rows
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+1)/2;
    localparam PAD = WIDTH % 2;
    wire [WIDTH+PAD:0] y_ext = {{PAD{multiplier[WIDTH-1]}}, multiplier, 1'b0};
    wire signed [PW-1:0] m_ext = {{WIDTH{multiplicand[WIDTH-1]}}, multiplicand};

    function signed [PW-1:0] decode;
        input [2:0] code;
        input signed [PW-1:0] m;
        begin
            case (code)
                3'b000, 3'b111: decode = 0;
                3'b001, 3'b010: decode = m;
                3'b011: decode = m <<< 1;
                3'b100: decode = -(m <<< 1);
                3'b101, 3'b110: decode = -m;
                default: decode = 0;
            endcase
        end
    endfunction

    genvar k;
    generate for (k = 0; k < ROWS; k = k + 1) begin: g_row
        wire [2:0] code = y_ext[2*k+2 -: 3];
        wire signed [PW-1:0] selected = decode(code, m_ext);
        assign rows[k*PW +: PW] = selected <<< (2*k);
    end endgenerate
endmodule
