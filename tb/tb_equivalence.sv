`timescale 1ns/1ps
module tb_equivalence;
    parameter W = 8;
    localparam MIN_VALUE = -(1 << (W-1));
    localparam MAX_VALUE = (1 << (W-1)) - 1;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg start = 0;
    reg signed [W-1:0] a = 0, b = 0;
    wire signed [2*W-1:0] p_r2, p_r4i, p_r8i, p_r4p, p_csa, p_r8, p_r8c, p_pipe, p_base;
    wire busy_r2, done_r2, busy_r4, done_r4, busy_r8, done_r8;
    wire valid_pipe;
    integer cases = 0;
    integer errors = 0;
    integer wait_cycles;
    reg seen_r2, seen_r4, seen_r8, seen_pipe;
    reg signed [2*W-1:0] expected;
    integer i, j;

    booth_radix2_iter #(.WIDTH(W)) d_r2(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r2), .busy(busy_r2), .done(done_r2));
    booth_radix4_iter #(.WIDTH(W)) d_r4i(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r4i), .busy(busy_r4), .done(done_r4));
    booth_radix8_iter #(.WIDTH(W)) d_r8i(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p_r8i), .busy(busy_r8), .done(done_r8));
    booth_radix4_parallel #(.WIDTH(W)) d_r4p(
        .multiplicand(a), .multiplier(b), .product(p_r4p));
    booth_radix4_csa #(.WIDTH(W)) d_csa(
        .multiplicand(a), .multiplier(b), .product(p_csa));
    booth_radix8_parallel #(.WIDTH(W)) d_r8(
        .multiplicand(a), .multiplier(b), .product(p_r8));
    booth_radix8_csa #(.WIDTH(W)) d_r8c(
        .multiplicand(a), .multiplier(b), .product(p_r8c));
    booth_radix4_pipe #(.WIDTH(W)) d_pipe(
        .clk(clk), .rst(rst), .in_valid(start),
        .multiplicand(a), .multiplier(b), .product(p_pipe), .out_valid(valid_pipe));
    mul_inferred #(.WIDTH(W)) d_base(
        .multiplicand(a), .multiplier(b), .product(p_base));

    task automatic run_case(input integer x, input integer y);
        begin
            @(negedge clk);
            a = W'(x); // Random 32-bit values are intentionally reduced to W bits.
            b = W'(y);
            expected = $signed(a) * $signed(b); // Testbench oracle only.
            #1;
            if (p_r4p !== expected || p_csa !== expected || p_r8 !== expected ||
                p_r8c !== expected || p_base !== expected) begin
                $display("FAIL parallel W=%0d a=%0d b=%0d ref=%0d r4=%0d csa=%0d r8=%0d r8c=%0d base=%0d",
                         W, a, b, expected, p_r4p, p_csa, p_r8, p_r8c, p_base);
                errors = errors + 1;
            end
            start = 1;
            @(negedge clk);
            start = 0;
            seen_r2 = 0;
            seen_r4 = 0;
            seen_r8 = 0;
            seen_pipe = 0;
            wait_cycles = 0;
            while ((!seen_r2 || !seen_r4 || !seen_r8 || !seen_pipe) && wait_cycles < W+3) begin
                @(negedge clk);
                if (done_r2) seen_r2 = 1;
                if (done_r4) seen_r4 = 1;
                if (done_r8) seen_r8 = 1;
                if (valid_pipe) begin
                    seen_pipe = 1;
                    if (p_pipe !== expected) begin
                        $display("FAIL pipeline W=%0d a=%0d b=%0d expected=%0d got=%0d",
                                 W, a, b, expected, p_pipe);
                        errors = errors + 1;
                    end
                end
                wait_cycles = wait_cycles + 1;
            end
            if (!seen_r2 || !seen_r4 || !seen_r8 || !seen_pipe ||
                p_r2 !== expected || p_r4i !== expected || p_r8i !== expected) begin
                $display("FAIL sequential W=%0d a=%0d b=%0d ref=%0d r2=%0d r4=%0d r8=%0d seen=%b%b%b%b",
                         W, a, b, expected, p_r2, p_r4i, p_r8i,
                         seen_r2, seen_r4, seen_r8, seen_pipe);
                errors = errors + 1;
            end
            cases = cases + 1;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst = 0;
        run_case(0, 0);
        run_case(1, 1);
        run_case(-1, -1);
        run_case(MIN_VALUE, MIN_VALUE);
        run_case(MIN_VALUE, -1);
        run_case(MIN_VALUE, MAX_VALUE);
        run_case(MAX_VALUE, MAX_VALUE);
        run_case(1, MIN_VALUE);
        run_case(MAX_VALUE, -1);
        if (W <= 7) begin
            for (i = MIN_VALUE; i <= MAX_VALUE; i = i+1)
                for (j = MIN_VALUE; j <= MAX_VALUE; j = j+1)
                    run_case(i, j);
        end else begin
            for (i = 0; i < 500; i = i+1)
                run_case($random, $random);
        end
        if (errors == 0) $display("PASS W=%0d cases=%0d eight Booth architectures plus baseline", W, cases);
        else $fatal(1, "FAIL W=%0d errors=%0d of %0d", W, errors, cases);
        $finish;
    end
endmodule
