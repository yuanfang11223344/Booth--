`timescale 1ns/1ps
// Radix-8 rows followed by a linear carry-propagate adder chain.
module booth_radix8_parallel #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire signed [2*WIDTH-1:0] product
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+2)/3;
    wire [ROWS*PW-1:0] pp_rows;
    wire [PW-1:0] running_sum [0:ROWS];
    assign running_sum[0] = 0;
    booth_radix8_pp #(.WIDTH(WIDTH)) pp(
        .multiplicand(multiplicand), .multiplier(multiplier), .rows(pp_rows));
    genvar k;
    generate for (k = 0; k < ROWS; k = k + 1) begin: g_sum
        assign running_sum[k+1] = running_sum[k] + pp_rows[k*PW +: PW];
    end endgenerate
    assign product = running_sum[ROWS];
endmodule
