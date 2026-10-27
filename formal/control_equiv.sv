// External control-contract proof, separated from the multiplier datapath.
// Inputs and reset remain unconstrained at every SAT time step.
module iter_control_equiv #(
    parameter WIDTH = 8,
    parameter ARCH = 2
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
    wire signed [2*WIDTH-1:0] unused_product;
    wire busy, done;
    generate
        if (ARCH == 2) begin: radix2
            booth_radix2_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(unused_product), .busy(busy), .done(done));
        end else if (ARCH == 4) begin: radix4
            booth_radix4_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(unused_product), .busy(busy), .done(done));
        end else begin: radix8
            booth_radix8_iter #(.WIDTH(WIDTH)) dut(
                .clk(clk), .rst(rst), .start(start),
                .multiplicand(a), .multiplier(b),
                .product(unused_product), .busy(busy), .done(done));
        end
    endgenerate

    reg active, expected_done;
    reg [CW-1:0] elapsed;
    always @* begin
        assert (busy == active);
        assert (done == expected_done);
    end
    always @(posedge clk) begin
        if (rst) begin
            active <= 0;
            expected_done <= 0;
            elapsed <= 0;
        end else begin
            expected_done <= 0;
            if (!active && start) begin
                active <= 1;
                elapsed <= 0;
            end else if (active) begin
                if (elapsed == CYCLES-1) begin
                    active <= 0;
                    expected_done <= 1;
                end else begin
                    elapsed <= elapsed + 1'b1;
                end
            end
        end
    end
endmodule

module pipe_control_equiv #(
    parameter WIDTH = 8
) (
    input wire clk,
    input wire rst,
    input wire in_valid,
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b
);
    wire signed [2*WIDTH-1:0] unused_product;
    wire out_valid;
    booth_radix4_pipe #(.WIDTH(WIDTH)) dut(
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .multiplicand(a), .multiplier(b),
        .product(unused_product), .out_valid(out_valid));

    reg sampled_valid, expected_valid;
    always @* assert (out_valid == expected_valid);
    always @(posedge clk) begin
        if (rst) begin
            sampled_valid <= 0;
            expected_valid <= 0;
        end else begin
            sampled_valid <= in_valid;
            expected_valid <= sampled_valid;
        end
    end
endmodule
