`timescale 1ns/1ps
// Same radix-8 rows as the linear version, with CSA tree reduction.
module booth_radix8_csa #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire signed [2*WIDTH-1:0] product
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+2)/3;
    wire [ROWS*PW-1:0] pp_rows;
    wire [PW-1:0] sum, carry;
    booth_radix8_pp #(.WIDTH(WIDTH)) pp(
        .multiplicand(multiplicand), .multiplier(multiplier), .rows(pp_rows));
    csa_reduce #(.WIDTH(PW), .ROWS(ROWS)) tree(
        .operands(pp_rows), .sum(sum), .carry(carry));
    assign product = sum + carry;
endmodule
