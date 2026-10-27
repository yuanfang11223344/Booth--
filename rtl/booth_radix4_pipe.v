`timescale 1ns/1ps
// Two-register-stage, one-result-per-clock radix-4 Booth + CSA multiplier.
// A transaction sampled at edge N appears with out_valid at edge N+1.
module booth_radix4_pipe #(
    parameter WIDTH = 8
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     in_valid,
    input  wire signed [WIDTH-1:0]  multiplicand,
    input  wire signed [WIDTH-1:0]  multiplier,
    output reg  signed [2*WIDTH-1:0] product,
    output reg                      out_valid
);
    localparam PW = 2*WIDTH;
    localparam ROWS = (WIDTH+1)/2;
    wire [ROWS*PW-1:0] pp_rows;
    reg [ROWS*PW-1:0] rows_reg;
    reg valid_reg;
    wire [PW-1:0] sum, carry;

    booth_radix4_pp #(.WIDTH(WIDTH)) pp(
        .multiplicand(multiplicand), .multiplier(multiplier), .rows(pp_rows));
    csa_reduce #(.WIDTH(PW), .ROWS(ROWS)) tree(
        .operands(rows_reg), .sum(sum), .carry(carry));

    always @(posedge clk) begin
        if (rst) begin
            rows_reg <= 0;
            valid_reg <= 0;
            product <= 0;
            out_valid <= 0;
        end else begin
            if (in_valid) rows_reg <= pp_rows;
            valid_reg <= in_valid;
            if (valid_reg) product <= sum + carry;
            out_valid <= valid_reg;
        end
    end
endmodule
