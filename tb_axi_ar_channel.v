`timescale 1ns/1ps

module tb_axi_ar_channel;

    parameter ADDR_WIDTH     = 32;
    parameter BURST_LEN_BITS = 4;

    reg                       clk;
    reg                       aresetn;
    reg  [ADDR_WIDTH-1:0]     s_axi_araddr;
    reg  [BURST_LEN_BITS-1:0] s_axi_arlen;
    reg  [1:0]                s_axi_arburst;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;
    reg                       ar_pipe_busy;

    wire [ADDR_WIDTH-1:0]     ar_captured_addr;
    wire [BURST_LEN_BITS-1:0] ar_captured_len;
    wire [1:0]                ar_captured_burst;
    wire                      ar_handshake_done;

    // Instantiate UUT
    axi_ar_channel #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_LEN_BITS(BURST_LEN_BITS)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .ar_pipe_busy(ar_pipe_busy),
        .ar_captured_addr(ar_captured_addr),
        .ar_captured_len(ar_captured_len),
        .ar_captured_burst(ar_captured_burst),
        .ar_handshake_done(ar_handshake_done)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk           = 0;
        aresetn       = 0;
        s_axi_araddr  = 32'h0;
        s_axi_arlen   = 4'd0;
        s_axi_arburst = 2'b00;
        s_axi_arvalid = 1'b0;
        ar_pipe_busy  = 1'b0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_ar_channel Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Normal Read Address Handshake
        // =========================================================
        @(posedge clk);
        s_axi_araddr  = 32'h0000_0014;
        s_axi_arlen   = 4'd7;   // 8 beats
        s_axi_arburst = 2'b01;  // INCR
        s_axi_arvalid = 1'b1;

        @(posedge clk);
        #1;
        if (ar_handshake_done && 
            (ar_captured_addr === 32'h0000_0014) && 
            (ar_captured_len === 4'd7) && 
            (ar_captured_burst === 2'b01)) begin
            $display("[PASS] TEST 1: Read address handshake logged properly.");
        end else begin
            $display("[FAIL] TEST 1: Handshake or capture failure!");
            $finish;
        end

        s_axi_arvalid = 1'b0;

        // =========================================================
        // TEST 2: Pipeline Busy Backpressure
        // =========================================================
        @(posedge clk);
        ar_pipe_busy = 1'b1; // Simulate active read burst in progress

        @(posedge clk);
        #1;
        if (!s_axi_arready) begin
            $display("[PASS] TEST 2: arready deasserted while read datapath is busy.");
        end else begin
            $display("[FAIL] TEST 2: arready stayed high during busy state!");
            $finish;
        end

        // Master tries presenting an address while busy
        s_axi_araddr  = 32'h0000_0080;
        s_axi_arvalid = 1'b1;
        @(posedge clk);
        #1;
        if (!ar_handshake_done && (ar_captured_addr === 32'h0000_0014)) begin
            $display("[PASS] TEST 2: New request rejected and old address preserved.");
        end else begin
            $display("[FAIL] TEST 2: Address overwritten during busy state!");
            $finish;
        end

        // =========================================================
        // TEST 3: Pipeline Release & Handshake Recovery
        // =========================================================
        ar_pipe_busy = 1'b0; // Release pipeline
        @(posedge clk);
        @(posedge clk);
        #1;
        if (ar_handshake_done && (ar_captured_addr === 32'h0000_0080)) begin
            $display("[PASS] TEST 3: Handshake accepted after pipeline freed.");
        end else begin
            $display("[FAIL] TEST 3: Recovery failed!");
            $finish;
        end

        s_axi_arvalid = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 3 AXI_AR_CHANNEL TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule