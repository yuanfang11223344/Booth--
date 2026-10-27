// SAT miter: every possible input bit pattern at the selected WIDTH.
module comb_equiv #(
    parameter WIDTH = 4
) (
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b
);
    wire signed [2*WIDTH-1:0] reference_product = a * b;
    wire signed [2*WIDTH-1:0] r4_linear, r4_csa, r8_linear, r8_csa;
    booth_radix4_parallel #(.WIDTH(WIDTH)) m_r4_linear(a,b,r4_linear);
    booth_radix4_csa #(.WIDTH(WIDTH)) m_r4_csa(a,b,r4_csa);
    booth_radix8_parallel #(.WIDTH(WIDTH)) m_r8_linear(a,b,r8_linear);
    booth_radix8_csa #(.WIDTH(WIDTH)) m_r8_csa(a,b,r8_csa);
    always @* begin
        assert (r4_linear == reference_product);
        assert (r4_csa == reference_product);
        assert (r8_linear == reference_product);
        assert (r8_csa == reference_product);
    end
endmodule

module unsigned_equiv #(
    parameter WIDTH = 4
) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b
);
    wire [2*WIDTH-1:0] reference_product = a * b;
    wire [2*WIDTH-1:0] actual_product;
    booth_radix4_unsigned #(.WIDTH(WIDTH)) dut(a,b,actual_product);
    always @* assert (actual_product == reference_product);
endmodule

// Smaller miter for SAT runs at wider widths. ARCH: 0=r4 linear, 1=r4 CSA,
// 2=r8 linear, 3=r8 CSA. The inactive architectures are not elaborated.
module one_equiv #(
    parameter WIDTH = 8,
    parameter ARCH = 0
) (
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b
);
    wire signed [2*WIDTH-1:0] reference_product = a * b;
    wire signed [2*WIDTH-1:0] actual_product;
    generate
        if (ARCH == 0) begin: g_r4_linear
            booth_radix4_parallel #(.WIDTH(WIDTH)) dut(a,b,actual_product);
        end else if (ARCH == 1) begin: g_r4_csa
            booth_radix4_csa #(.WIDTH(WIDTH)) dut(a,b,actual_product);
        end else if (ARCH == 2) begin: g_r8_linear
            booth_radix8_parallel #(.WIDTH(WIDTH)) dut(a,b,actual_product);
        end else begin: g_r8_csa
            booth_radix8_csa #(.WIDTH(WIDTH)) dut(a,b,actual_product);
        end
    endgenerate
    always @* assert (actual_product == reference_product);
endmodule
