`timescale 1ns/1ps
module tb_unsigned;
    parameter W = 8;
    localparam MAX_VALUE = (1 << W) - 1;
    reg [W-1:0] a = 0, b = 0;
    wire [2*W-1:0] product;
    reg [2*W-1:0] expected;
    integer i, j, cases = 0;
    booth_radix4_unsigned #(.WIDTH(W)) dut(
        .multiplicand(a), .multiplier(b), .product(product));

    task automatic check(input integer x, input integer y);
        begin
            a = W'(x); // Exercise the W-bit unsigned input domain.
            b = W'(y);
            expected = $unsigned(a) * $unsigned(b);
            #1;
            if (product !== expected)
                $fatal(1, "unsigned W=%0d a=%0d b=%0d got=%0d expected=%0d",
                       W, a, b, product, expected);
            cases = cases+1;
        end
    endtask
    initial begin
        check(0, 0);
        check(1, MAX_VALUE);
        check(MAX_VALUE, MAX_VALUE);
        if (W <= 7) begin
            for (i = 0; i <= MAX_VALUE; i = i+1)
                for (j = 0; j <= MAX_VALUE; j = j+1)
                    check(i, j);
        end else begin
            for (i = 0; i < 500; i = i+1)
                check($random, $random);
        end
        $display("PASS unsigned W=%0d cases=%0d", W, cases);
        $finish;
    end
endmodule
