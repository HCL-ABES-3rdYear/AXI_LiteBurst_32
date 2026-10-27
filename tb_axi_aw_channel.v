`timescale 1ns/1ps

module tb_axi_aw_channel;

    parameter ADDR_WIDTH     = 32;
    parameter BURST_LEN_BITS = 4;

    reg                       clk;
    reg                       aresetn;
    reg  [ADDR_WIDTH-1:0]     s_axi_awaddr;
    reg  [BURST_LEN_BITS-1:0] s_axi_awlen;
    reg  [1:0]                s_axi_awburst;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;
    reg                       aw_fifo_full;
    wire [ADDR_WIDTH-1:0]     aw_captured_addr;
    wire [BURST_LEN_BITS-1:0] aw_captured_len;
    wire [1:0]                aw_captured_burst;
    wire                      aw_handshake_done;

    // Instantiate Unit Under Test (UUT)
    axi_aw_channel #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_LEN_BITS(BURST_LEN_BITS)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .aw_fifo_full(aw_fifo_full),
        .aw_captured_addr(aw_captured_addr),
        .aw_captured_len(aw_captured_len),
        .aw_captured_burst(aw_captured_burst),
        .aw_handshake_done(aw_handshake_done)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    initial begin
        clk           = 0;
        aresetn       = 0;
        s_axi_awaddr  = 32'h0;
        s_axi_awlen   = 4'd0;
        s_axi_awburst = 2'b00;
        s_axi_awvalid = 1'b0;
        aw_fifo_full  = 1'b0;

        // Reset sequence
        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_aw_channel Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Standard Handshake Transfer
        // =========================================================
        @(posedge clk);
        s_axi_awaddr  = 32'h0000_0010;
        s_axi_awlen   = 4'd3;   // 4 beats
        s_axi_awburst = 2'b01;  // INCR
        s_axi_awvalid = 1'b1;

        @(posedge clk);
        #1;
        if (aw_handshake_done && (aw_captured_addr === 32'h0000_0010) && 
            (aw_captured_len === 4'd3) && (aw_captured_burst === 2'b01)) begin
            $display("[PASS] TEST 1: Handshake executed and inputs captured successfully.");
        end else begin
            $display("[FAIL] TEST 1: Handshake or capture failure!");
            $finish;
        end

        s_axi_awvalid = 1'b0;

        // =========================================================
        // TEST 2: Backpressure (Slave is full -> awready must fall)
        // =========================================================
        @(posedge clk);
        aw_fifo_full  = 1'b1; // Simulate internal write pipeline full

        @(posedge clk);
        #1;
        if (s_axi_awready === 1'b0) begin
            $display("[PASS] TEST 2: awready pulled low due to backpressure.");
        end else begin
            $display("[FAIL] TEST 2: awready did not drop on backpressure!");
            $finish;
        end

        // Master tries to send address during backpressure
        s_axi_awaddr  = 32'h0000_0050;
        s_axi_awvalid = 1'b1;
        @(posedge clk);
        #1;
        if (aw_handshake_done === 1'b0 && aw_captured_addr === 32'h0000_0010) begin
            $display("[PASS] TEST 2: Handshake prevented during backpressure (old data safe).");
        end else begin
            $display("[FAIL] TEST 2: Latching occurred while full!");
            $finish;
        end

        // =========================================================
        // TEST 3: Backpressure Release & Immediate Handshake
        // =========================================================
        aw_fifo_full = 1'b0; // Free pipeline
        @(posedge clk);
        @(posedge clk);
        #1;
        if (aw_handshake_done && (aw_captured_addr === 32'h0000_0050)) begin
            $display("[PASS] TEST 3: Handshake recovered cleanly after backpressure released.");
        end else begin
            $display("[FAIL] TEST 3: Recovery failed!");
            $finish;
        end

        s_axi_awvalid = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 3 AXI_AW_CHANNEL TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule