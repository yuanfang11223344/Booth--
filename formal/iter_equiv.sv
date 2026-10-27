// Sequential miter for a complete radix-2, radix-4 or radix-8 transaction.
// The scoreboard uses multiplication only for the expected result; it models
// start acceptance, latency, reset cancellation, done pulses and result hold.
module iter_equiv #(
    parameter WIDTH = 4,
    parameter ARCH = 2,
    parameter REFERENCE = 0
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b
);
    localparam CYCLES = (ARCH == 2) ? WIDTH :
                        (ARCH == 4) ? (WIDTH+1)/2 : (WIDTH+2)/3;
    localparam CW = $clog2(CYCLES + 1);
    wire signed [2*WIDTH-1:0] product;
    wire busy, done;
    generate
        if (ARCH == 2) begin: radix2
            booth_radix2_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(product), .busy(busy), .done(done));
        end else if (ARCH == 4) begin: radix4
            booth_radix4_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(product), .busy(busy), .done(done));
        end else begin: radix8
            booth_radix8_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(product), .busy(busy), .done(done));
        end
    endgenerate

    reg expected_busy, expected_done;
    reg [CW-1:0] age;
    reg signed [2*WIDTH-1:0] expected_product, pending_product;
    wire signed [2*WIDTH-1:0] reference_product;
    generate
        if (REFERENCE == 0) begin: direct_reference
            assign reference_product = a * b;
        end else begin: composed_reference
            booth_radix4_csa #(.WIDTH(WIDTH)) golden(a,b,reference_product);
        end
    endgenerate
    always @* begin
        assert (busy == expected_busy);
        assert (done == expected_done);
        assert (product == expected_product);
    end
    always @(posedge clk) begin
        if (rst) begin
            expected_busy <= 0;
            expected_done <= 0;
            expected_product <= 0;
            pending_product <= 0;
            age <= 0;
        end else begin
            expected_done <= 0;
            if (start && !expected_busy) begin
                pending_product <= reference_product;
                expected_busy <= 1;
                age <= 0;
            end else if (expected_busy) begin
                age <= age + 1'b1;
                if (age == CYCLES-1) begin
                    expected_product <= pending_product;
                    expected_busy <= 0;
                    expected_done <= 1;
                end
            end
        end
    end
endmodule
