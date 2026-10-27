`timescale 1ns/1ps

module tb_axi_b_channel;

    reg        clk;
    reg        aresetn;
    reg        wr_complete_pulse;
    reg  [1:0] gen_bresp;
    wire [1:0] s_axi_bresp;
    wire       s_axi_bvalid;
    reg        s_axi_bready;
    wire       b_handshake_done;

    axi_b_channel uut (
        .clk(clk),
        .aresetn(aresetn),
        .wr_complete_pulse(wr_complete_pulse),
        .gen_bresp(gen_bresp),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .b_handshake_done(b_handshake_done)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk               = 0;
        aresetn           = 0;
        wr_complete_pulse = 0;
        gen_bresp         = 2'b00;
        s_axi_bready      = 0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_b_channel Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Immediate Handshake (BREADY already HIGH)
        // =========================================================
        @(posedge clk);
        s_axi_bready      = 1'b1;
        gen_bresp         = 2'b00; // OKAY
        wr_complete_pulse = 1'b1;

        @(posedge clk);
        #1;
        wr_complete_pulse = 1'b0;
        if (s_axi_bvalid && (s_axi_bresp === 2'b00) && b_handshake_done) begin
            $display("[PASS] TEST 1: Response OKAY transferred in single cycle.");
        end else begin
            $display("[FAIL] TEST 1: Immediate handshake failed!");
            $finish;
        end

        @(posedge clk);
        #1;
        if (!s_axi_bvalid) begin
            $display("[PASS] TEST 1: BVALID cleanly deasserted post-handshake.");
        end else begin
            $display("[FAIL] TEST 1: BVALID stuck high!");
            $finish;
        end

        // =========================================================
        // TEST 2: Master Backpressure (BREADY is LOW, BVALID waits)
        // =========================================================
        s_axi_bready      = 1'b0; // Master not ready
        gen_bresp         = 2'b10; // SLVERR
        wr_complete_pulse = 1'b1;

        @(posedge clk);
        #1;
        wr_complete_pulse = 1'b0;
        if (s_axi_bvalid && (s_axi_bresp === 2'b10) && !b_handshake_done) begin
            $display("[PASS] TEST 2: BVALID asserted and waiting for BREADY.");
        end else begin
            $display("[FAIL] TEST 2: BVALID did not assert properly!");
            $finish;
        end

        // Wait 2 idle cycles; verify BVALID and BRESP remain rock solid
        repeat (2) @(posedge clk);
        #1;
        if (s_axi_bvalid && (s_axi_bresp === 2'b10)) begin
            $display("[PASS] TEST 2: Signals remained stable during master stall.");
        end else begin
            $display("[FAIL] TEST 2: Signals destabilized while waiting for BREADY!");
            $finish;
        end

        // Master now asserts BREADY
        s_axi_bready = 1'b1;
        @(posedge clk);
        #1;
        if (b_handshake_done) begin
            $display("[PASS] TEST 2: Handshake completed cleanly when BREADY arrived.");
        end else begin
            $display("[FAIL] TEST 2: Handshake failed to close!");
            $finish;
        end

        s_axi_bready = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 2 AXI_B_CHANNEL TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule