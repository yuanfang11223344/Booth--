`timescale 1ns/1ps
// Unsigned W x W multiply via a (W+1)-bit signed radix-4 Booth core.
// Leading zeros make both unsigned inputs nonnegative in the signed core.
module booth_radix4_unsigned #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] multiplicand,
    input  wire [WIDTH-1:0] multiplier,
    output wire [2*WIDTH-1:0] product
);
    wire signed [2*(WIDTH+1)-1:0] extended_product;
    // The mathematically exact unsigned result fits 2*WIDTH bits.
    wire unused_high_bits = ^extended_product[2*WIDTH+1:2*WIDTH];
    booth_radix4_csa #(.WIDTH(WIDTH+1)) core(
        .multiplicand({1'b0, multiplicand}),
        .multiplier({1'b0, multiplier}),
        .product(extended_product));
    assign product = extended_product[2*WIDTH-1:0];
endmodule
