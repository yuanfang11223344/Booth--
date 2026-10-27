`timescale 1ns/1ps
// Directed interface checks beyond arithmetic equivalence.
module tb_control;
    localparam W = 8;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, start = 0;
    reg signed [W-1:0] a = 0, b = 0;
    wire signed [2*W-1:0] p2, p4, p8;
    wire busy2, busy4, busy8, done2, done4, done8;
    integer ticks;
    reg seen2, seen4, seen8;

    booth_radix2_iter #(.WIDTH(W)) r2(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p2), .busy(busy2), .done(done2));
    booth_radix4_iter #(.WIDTH(W)) r4(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p4), .busy(busy4), .done(done4));
    booth_radix8_iter #(.WIDTH(W)) r8(
        .clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
        .product(p8), .busy(busy8), .done(done8));

    task automatic launch(input signed [W-1:0] x, input signed [W-1:0] y);
        begin
            @(negedge clk);
            a = x;
            b = y;
            start = 1;
            @(negedge clk);
            start = 0;
        end
    endtask

    task automatic await_all(input signed [2*W-1:0] expected);
        begin
            seen2 = 0;
            seen4 = 0;
            seen8 = 0;
            ticks = 0;
            while ((!seen2 || !seen4 || !seen8) && ticks < W+3) begin
                @(posedge clk);
                #1;
                if (done2) seen2 = 1;
                if (done4) seen4 = 1;
                if (done8) seen8 = 1;
                ticks = ticks + 1;
            end
            if (!seen2 || !seen4 || !seen8 ||
                p2 !== expected || p4 !== expected || p8 !== expected)
                $fatal(1, "Completion/result failure p2=%0d p4=%0d p8=%0d expected=%0d",
                       p2, p4, p8, expected);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst = 0;
        launch(13, -7);
        if (!busy2 || !busy4 || !busy8) $fatal(1, "All engines must be busy after start");

        // Change external operands and pulse start while all engines are busy.
        // The captured first transaction must remain 13 * -7.
        a = -128;
        b = -1;
        start = 1;
        @(negedge clk);
        start = 0;
        await_all(-91);
        @(posedge clk);
        #1;
        if (done2 || done4 || done8 || busy2 || busy4 || busy8 ||
            p2 !== -91 || p4 !== -91 || p8 !== -91)
            $fatal(1, "done must pulse; products must hold while idle");

        // A synchronous reset must cancel an incomplete transaction.
        launch(7, 11);
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #1;
        if (busy2 || busy4 || busy8 || done2 || done4 || done8 ||
            p2 !== 0 || p4 !== 0 || p8 !== 0)
            $fatal(1, "reset did not clear in-flight transaction");
        @(negedge clk);
        rst = 0;

        launch(-128, -1);
        await_all(128);
        $display("PASS interface: busy-start ignored, done pulse, hold, reset cancel, restart");
        $finish;
    end
endmodule
