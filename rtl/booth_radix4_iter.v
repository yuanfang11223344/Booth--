`timescale 1ns/1ps
// One radix-4 partial product is accumulated per busy clock.
module booth_radix4_iter #(
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
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+1)/2;
    localparam PAD = WIDTH % 2;
    localparam COUNT_WIDTH = $clog2(ROWS + 1);
    localparam integer LAST = ROWS-1;
    localparam [COUNT_WIDTH-1:0] ROWS_COUNT = ROWS[COUNT_WIDTH-1:0];
    localparam [COUNT_WIDTH-1:0] LAST_COUNT = LAST[COUNT_WIDTH-1:0];
    reg signed [WIDTH-1:0] m_reg, y_reg;
    reg signed [PW-1:0] accumulator;
    reg [COUNT_WIDTH-1:0] count;
    wire [WIDTH+PAD:0] y_ext = {{PAD{y_reg[WIDTH-1]}}, y_reg, 1'b0};
    wire signed [PW-1:0] m_ext = {{WIDTH{m_reg[WIDTH-1]}}, m_reg};
    // Select one overlapping 3-bit group. There is only one digit decoder.
    wire [2:0] code = (count < ROWS_COUNT) ?
        y_ext[2*count+2 -: 3] : 3'b000;
    function signed [PW-1:0] decode;
        input [2:0] bits;
        input signed [PW-1:0] m;
        begin
            case (bits)
                3'b000, 3'b111: decode = 0;
                3'b001, 3'b010: decode = m;
                3'b011: decode = m <<< 1;
                3'b100: decode = -(m <<< 1);
                3'b101, 3'b110: decode = -m;
                default: decode = 0;
            endcase
        end
    endfunction
    wire signed [PW-1:0] selected_row = decode(code, m_ext) <<< (2*count);

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
