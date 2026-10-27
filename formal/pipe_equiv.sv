// Sequential scoreboard for the two-register-stage Booth pipeline.
// Inputs, valid gaps, back-to-back transactions and synchronous resets
// remain unconstrained in the SAT unrolling.
module pipe_equiv #(
    parameter WIDTH = 4,
    parameter REFERENCE = 0
) (
    input wire clk,
    input wire rst,
    input wire in_valid,
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b
);
    wire signed [2*WIDTH-1:0] product;
    wire out_valid;
    booth_radix4_pipe #(.WIDTH(WIDTH)) dut(
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .multiplicand(a), .multiplier(b),
        .product(product), .out_valid(out_valid));

    reg pending_valid, expected_valid;
    reg signed [2*WIDTH-1:0] pending_product, expected_product;
    wire signed [2*WIDTH-1:0] reference_product;
    generate
        if (REFERENCE == 0) begin: direct_reference
            assign reference_product = a * b;
        end else begin: composed_reference
            booth_radix4_csa #(.WIDTH(WIDTH)) golden(a,b,reference_product);
        end
    endgenerate
    always @* begin
        assert (out_valid == expected_valid);
        assert (product == expected_product);
    end
    always @(posedge clk) begin
        if (rst) begin
            pending_valid <= 0;
            expected_valid <= 0;
            pending_product <= 0;
            expected_product <= 0;
        end else begin
            pending_valid <= in_valid;
            if (in_valid) pending_product <= reference_product;
            expected_valid <= pending_valid;
            if (pending_valid) expected_product <= pending_product;
        end
    end
endmodule
