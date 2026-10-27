`timescale 1ns/1ps

module tb_axi_r_channel;

    parameter DATA_WIDTH = 32;

    reg                   clk;
    reg                   aresetn;
    reg  [DATA_WIDTH-1:0] staged_rdata;
    reg                   staged_rvalid;
    reg  [1:0]            gen_rresp;
    reg                   is_last_beat;
    wire [DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]            s_axi_rresp;
    wire                  s_axi_rlast;
    wire                  s_axi_rvalid;
    reg                   s_axi_rready;
    wire                  r_beat_ack;
    wire                  r_busy;

    // Instantiate UUT
    axi_r_channel #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .staged_rdata(staged_rdata),
        .staged_rvalid(staged_rvalid),
        .gen_rresp(gen_rresp),
        .is_last_beat(is_last_beat),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .r_beat_ack(r_beat_ack),
        .r_busy(r_busy)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk           = 0;
        aresetn       = 0;
        staged_rdata  = 32'h0;
        staged_rvalid = 0;
        gen_rresp     = 2'b00;
        is_last_beat  = 0;
        s_axi_rready  = 0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_r_channel Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Single Beat Handshake with RREADY already HIGH
        // =========================================================
        @(posedge clk);
        s_axi_rready  = 1'b1;
        staged_rdata  = 32'h1122_3344;
        gen_rresp     = 2'b00; // OKAY
        is_last_beat  = 1'b1;
        staged_rvalid = 1'b1;

        @(posedge clk);
        #1;
        staged_rvalid = 1'b0;
        if (r_beat_ack && (s_axi_rdata === 32'h1122_3344) && s_axi_rlast) begin
            $display("[PASS] TEST 1: Single beat with RLAST transferred cleanly.");
        end else begin
            $display("[FAIL] TEST 1: Single beat transfer failed!");
            $finish;
        end

        // =========================================================
        // TEST 2: Master Backpressure (RREADY is LOW, data holds stable)
        // =========================================================
        @(posedge clk);
        s_axi_rready  = 1'b0; // Master not ready
        staged_rdata  = 32'h5566_7788;
        gen_rresp     = 2'b10; // SLVERR
        is_last_beat  = 1'b0;
        staged_rvalid = 1'b1;

        @(posedge clk);
        #1;
        staged_rvalid = 1'b0;
        if (s_axi_rvalid && !r_beat_ack && (s_axi_rdata === 32'h5566_7788)) begin
            $display("[PASS] TEST 2: RVALID asserted and holding while RREADY is low.");
        end else begin
            $display("[FAIL] TEST 2: Stall entry failed!");
            $finish;
        end

        // Check stability over 2 stall clock cycles
        repeat (2) @(posedge clk);
        #1;
        if ((s_axi_rdata === 32'h5566_7788) && (s_axi_rresp === 2'b10) && s_axi_rvalid) begin
            $display("[PASS] TEST 2: Signals remained completely stable during stall.");
        end else begin
            $display("[FAIL] TEST 2: Signals glitched or retracted during stall!");
            $finish;
        end

        // Master asserts RREADY
        s_axi_rready = 1'b1;
        @(posedge clk);
        #1;
        if (r_beat_ack) begin
            $display("[PASS] TEST 2: Handshake completed once RREADY asserted.");
        end else begin
            $display("[FAIL] TEST 2: Handshake failed to clear!");
            $finish;
        end

        s_axi_rready = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 2 AXI_R_CHANNEL TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule