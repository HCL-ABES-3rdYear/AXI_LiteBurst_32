`timescale 1ns/1ps

module tb_axi_w_channel;

    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = DATA_WIDTH / 8;

    reg                   clk;
    reg                   aresetn;
    reg  [DATA_WIDTH-1:0] s_axi_wdata;
    reg  [STRB_WIDTH-1:0] s_axi_wstrb;
    reg                   s_axi_wlast;
    reg                   s_axi_wvalid;
    wire                  s_axi_wready;
    reg                   w_fifo_full;
    reg                   expected_last_beat;

    wire [DATA_WIDTH-1:0] w_captured_data;
    wire [STRB_WIDTH-1:0] w_captured_strb;
    wire                  w_captured_last;
    wire                  w_beat_ack;
    wire                  wlast_error;

    // Instantiate UUT
    axi_w_channel #(
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .w_fifo_full(w_fifo_full),
        .expected_last_beat(expected_last_beat),
        .w_captured_data(w_captured_data),
        .w_captured_strb(w_captured_strb),
        .w_captured_last(w_captured_last),
        .w_beat_ack(w_beat_ack),
        .wlast_error(wlast_error)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk                = 0;
        aresetn            = 0;
        s_axi_wdata        = 32'h0;
        s_axi_wstrb        = 4'h0;
        s_axi_wlast        = 0;
        s_axi_wvalid       = 0;
        w_fifo_full        = 0;
        expected_last_beat = 0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_w_channel Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Single Normal Data Beat
        // =========================================================
        @(posedge clk);
        s_axi_wdata        = 32'hAAAA_BBBB;
        s_axi_wstrb        = 4'b1111;
        s_axi_wlast        = 1'b1;
        s_axi_wvalid       = 1'b1;
        expected_last_beat = 1'b1;

        @(posedge clk);
        #1;
        if (w_beat_ack && (w_captured_data === 32'hAAAA_BBBB) && 
            (w_captured_strb === 4'b1111) && (w_captured_last === 1'b1) && !wlast_error) begin
            $display("[PASS] TEST 1: Normal data beat transferred with valid strobes.");
        end else begin
            $display("[FAIL] TEST 1: Transfer failed!");
            $finish;
        end

        s_axi_wvalid = 1'b0;

        // =========================================================
        // TEST 2: Mid-Burst Backpressure (Full signal halts transfer)
        // =========================================================
        @(posedge clk);
        w_fifo_full = 1'b1;

        @(posedge clk);
        #1;
        if (!s_axi_wready) begin
            $display("[PASS] TEST 2: wready deasserted under backpressure.");
        end else begin
            $display("[FAIL] TEST 2: wready stayed high!");
            $finish;
        end

        // Master tries pushing data during backpressure
        s_axi_wdata  = 32'h1234_5678;
        s_axi_wvalid = 1'b1;
        @(posedge clk);
        #1;
        if (!w_beat_ack && (w_captured_data === 32'hAAAA_BBBB)) begin
            $display("[PASS] TEST 2: Master data rejected cleanly during backpressure.");
        end else begin
            $display("[FAIL] TEST 2: Data overwritten while full!");
            $finish;
        end

        // =========================================================
        // TEST 3: WLAST Mismatch Detection
        // =========================================================
        w_fifo_full        = 1'b0; // Release pressure
        s_axi_wdata        = 32'hDEAD_0001;
        s_axi_wstrb        = 4'b1100;
        s_axi_wvalid       = 1'b1;
        s_axi_wlast        = 1'b0; // Master says NOT last
        expected_last_beat = 1'b1; // Slave counter expected LAST beat

        @(posedge clk);
        @(posedge clk);
        #1;
        if (wlast_error) begin
            $display("[PASS] TEST 3: WLAST mismatch protocol violation correctly detected!");
        end else begin
            $display("[FAIL] TEST 3: wlast_error did not trigger on mismatch!");
            $finish;
        end

        s_axi_wvalid = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 3 AXI_W_CHANNEL TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule