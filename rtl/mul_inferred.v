`timescale 1ns/1ps
// Behavioral baseline: synthesis may infer a hard DSP or a soft multiplier.
// This is intentionally not a Booth implementation.
module mul_inferred #(
    parameter WIDTH = 8
) (
    input  wire signed [WIDTH-1:0] multiplicand,
    input  wire signed [WIDTH-1:0] multiplier,
    output wire signed [2*WIDTH-1:0] product
);
    assign product = multiplicand * multiplier;
endmodule
