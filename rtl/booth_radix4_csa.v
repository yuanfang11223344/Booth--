`timescale 1ns/1ps
// Modified Booth rows -> carry-save reduction -> one final carry-propagate add.
module booth_radix4_csa #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire signed [2*WIDTH-1:0] product
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+1)/2;
    wire [ROWS*PW-1:0] pp_rows;
    wire [PW-1:0] sum, carry;
    booth_radix4_pp #(.WIDTH(WIDTH)) pp(
        .multiplicand(multiplicand), .multiplier(multiplier), .rows(pp_rows));
    csa_reduce #(.WIDTH(PW), .ROWS(ROWS)) tree(
        .operands(pp_rows), .sum(sum), .carry(carry));
    assign product = sum + carry;
endmodule
