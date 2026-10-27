`timescale 1ns/1ps
// One radix-8 modified Booth digit and aligned partial product per busy clock.
// WIDTH >= 2. Signed two's-complement inputs; full 2*WIDTH-bit product.
module booth_radix8_iter #(
    parameter WIDTH = 8
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      start,
    input  wire signed [WIDTH-1:0]   multiplicand,
    input  wire signed [WIDTH-1:0]   multiplier,
    output reg  signed [2*WIDTH-1:0] product,
    output reg                       busy,
    output reg                       done
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+2)/3;
    localparam PAD = (3 - (WIDTH % 3)) % 3;
    localparam COUNT_WIDTH = $clog2(ROWS + 1);
    localparam integer LAST = ROWS-1;
    localparam [COUNT_WIDTH-1:0] ROWS_COUNT = ROWS[COUNT_WIDTH-1:0];
    localparam [COUNT_WIDTH-1:0] LAST_COUNT = LAST[COUNT_WIDTH-1:0];

    reg signed [WIDTH-1:0] m_reg, y_reg;
    reg signed [PW-1:0] accumulator;
    reg [COUNT_WIDTH-1:0] count;
    wire [WIDTH+PAD:0] y_ext = {{PAD{y_reg[WIDTH-1]}}, y_reg, 1'b0};
    wire signed [PW-1:0] m_ext = {{WIDTH{m_reg[WIDTH-1]}}, m_reg};
    wire signed [PW-1:0] triple_m = (m_ext <<< 1) + m_ext;
    wire [3:0] code = (count < ROWS_COUNT) ?
        y_ext[3*count+3 -: 4] : 4'b0000;

    function signed [PW-1:0] decode;
        input [3:0] bits;
        input signed [PW-1:0] m;
        input signed [PW-1:0] triple;
        begin
            case (bits)
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
    wire signed [PW-1:0] selected_row = decode(code, m_ext, triple_m) <<< (3*count);

    always @(posedge clk) begin
        if (rst) begin
            m_reg <= 0;
            y_reg <= 0;
            accumulator <= 0;
            count <= 0;
            product <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                m_reg <= multiplicand;
                y_reg <= multiplier;
                accumulator <= 0;
                count <= 0;
                busy <= 1;
            end else if (busy) begin
                accumulator <= accumulator + selected_row;
                count <= count + 1'b1;
                if (count == LAST_COUNT) begin
                    product <= accumulator + selected_row;
                    busy <= 0;
                    done <= 1;
                end
            end
        end
    end
endmodule
