`timescale 1ns/1ps
module tb_trace;
    parameter W = 8;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, start = 0;
    reg signed [W-1:0] a = 0, b = 0;
    wire signed [2*W-1:0] p_r2, p_r4i, p_r8i, p_r4p, p_csa, p_r8, p_r8c, p_pipe, p_base;
    wire busy_r2, done_r2, busy_r4, done_r4, busy_r8, done_r8;
    wire valid_pipe;
    integer x = 13, y = -7;
    integer cycle = 0;
    reg [1023:0] vcd_path;
    reg signed [2*W-1:0] ref_product;
    localparam signed [63:0] MIN_INPUT = -(64'sd1 <<< (W-1));
    localparam signed [63:0] MAX_INPUT = (64'sd1 <<< (W-1)) - 1;

    booth_radix2_iter #(.WIDTH(W)) r2(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r2), .busy(busy_r2), .done(done_r2));
    booth_radix4_iter #(.WIDTH(W)) r4i(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r4i), .busy(busy_r4), .done(done_r4));
    booth_radix8_iter #(.WIDTH(W)) r8i(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r8i), .busy(busy_r8), .done(done_r8));
    booth_radix4_parallel #(.WIDTH(W)) r4p(
        .multiplicand(a), .multiplier(b), .product(p_r4p));
    booth_radix4_csa #(.WIDTH(W)) csa(
        .multiplicand(a), .multiplier(b), .product(p_csa));
    booth_radix8_parallel #(.WIDTH(W)) r8(
        .multiplicand(a), .multiplier(b), .product(p_r8));
    booth_radix8_csa #(.WIDTH(W)) r8c(
        .multiplicand(a), .multiplier(b), .product(p_r8c));
    booth_radix4_pipe #(.WIDTH(W)) pipe_r4(
        .clk(clk), .rst(rst), .in_valid(start),
        .multiplicand(a), .multiplier(b), .product(p_pipe), .out_valid(valid_pipe));
    mul_inferred #(.WIDTH(W)) baseline(
        .multiplicand(a), .multiplier(b), .product(p_base));

    initial begin
        if ($value$plusargs("A=%d", x)) begin end
        if ($value$plusargs("B=%d", y)) begin end
        if (!$value$plusargs("VCD=%s", vcd_path)) vcd_path = "build/trace.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, tb_trace);
        repeat (2) @(negedge clk);
        rst = 0;
        if (64'(x) < MIN_INPUT || 64'(x) > MAX_INPUT ||
            64'(y) < MIN_INPUT || 64'(y) > MAX_INPUT)
            $fatal(1, "Operands out of W-bit range");
        a = W'(x);
        b = W'(y);
        ref_product = $signed(a) * $signed(b);
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        $display("W=%0d M=%0d Q=%0d reference=%0d", W, a, b, ref_product);
        $display("tick | radix2: A Q q- pair | radix4/radix8 accumulators | done 2/4/8");
        while (cycle < W+2) begin
            @(negedge clk);
            #1;
            $display("%4d | %6d %5d %b %b%b | %8d %8d | %8d | %b %b %b",
                     cycle, $signed(r2.a_reg), $signed(r2.q_reg), r2.q_minus,
                     r2.q_reg[0], r2.q_minus, $signed(r4i.accumulator),
                     $signed(r4i.selected_row), $signed(r8i.accumulator),
                     done_r2, done_r4, done_r8);
            cycle = cycle + 1;
            if (done_r2) begin
                if (p_r2 !== ref_product ||
                    p_r4i !== ref_product ||
                    p_r8i !== ref_product ||
                    p_r4p !== ref_product ||
                    p_csa !== ref_product ||
                    p_r8 !== ref_product ||
                    p_r8c !== ref_product ||
                    p_pipe !== ref_product ||
                    p_base !== ref_product)
                    $fatal(1, "Trace case result mismatch");
                $display("PASS all products = %0d", p_r2);
                $finish;
            end
        end
        $fatal(1, "Trace timeout");
    end
endmodule
