`timescale 1ns/1ps
// Back-to-back and gapped transactions through the radix-4 CSA pipeline.
module tb_pipeline;
    localparam W = 8;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, in_valid = 0;
    reg signed [W-1:0] a = 0, b = 0;
    wire signed [2*W-1:0] product;
    wire out_valid;
    reg prev_valid = 0;
    reg signed [2*W-1:0] prev_expected = 0;
    reg signed [2*W-1:0] current_expected;
    integer i, checked = 0;

    booth_radix4_pipe #(.WIDTH(W)) dut(
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .multiplicand(a), .multiplier(b),
        .product(product), .out_valid(out_valid));

    initial begin
        repeat (2) @(negedge clk);
        rst = 0;
        for (i = 0; i <= 16; i = i+1) begin
            @(negedge clk);
            in_valid = (i < 16) && (i % 5 != 2);
            a = W'(i*13 - 100);
            b = W'(7 - i);
            current_expected = $signed(a) * $signed(b);
            @(posedge clk);
            #1;
            if (out_valid !== prev_valid)
                $fatal(1, "pipeline valid misaligned at input slot %0d", i);
            if (prev_valid) begin
                if (product !== prev_expected)
                    $fatal(1, "pipeline product mismatch at slot %0d: got %0d expected %0d",
                           i, product, prev_expected);
                checked = checked + 1;
            end
            prev_valid = in_valid;
            prev_expected = current_expected;
        end
        if (checked != 13) $fatal(1, "Expected 13 checked pipeline outputs, got %0d", checked);

        // Cancel a just-sampled transaction with synchronous reset.
        @(negedge clk);
        in_valid = 1;
        a = -128;
        b = -1;
        @(posedge clk);
        #1;
        if (out_valid) $fatal(1, "early pipeline output");
        @(negedge clk);
        rst = 1;
        in_valid = 0;
        @(posedge clk);
        #1;
        if (out_valid || product !== 0) $fatal(1, "pipeline reset did not flush");
        $display("PASS pipeline: %0d outputs, bubbles, one-per-cycle throughput, reset flush", checked);
        $finish;
    end
endmodule
