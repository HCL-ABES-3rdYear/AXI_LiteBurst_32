`timescale 1ns/1ps

module tb_burst_controller;

    parameter ADDR_WIDTH     = 32;
    parameter DATA_WIDTH     = 32;
    parameter BURST_LEN_BITS = 4;

    reg                       clk;
    reg                       aresetn;
    reg                       burst_start;
    reg                       beat_ack;
    reg  [ADDR_WIDTH-1:0]     init_addr;
    reg  [BURST_LEN_BITS-1:0] burst_len;
    reg  [1:0]                burst_type;

    wire [ADDR_WIDTH-1:0]     current_addr;
    wire [BURST_LEN_BITS-1:0] current_beat;
    wire                      is_last_beat;
    wire                      burst_busy;

    // Instantiate Unit Under Test (UUT)
    burst_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LEN_BITS(BURST_LEN_BITS)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .burst_start(burst_start),
        .beat_ack(beat_ack),
        .init_addr(init_addr),
        .burst_len(burst_len),
        .burst_type(burst_type),
        .current_addr(current_addr),
        .current_beat(current_beat),
        .is_last_beat(is_last_beat),
        .burst_busy(burst_busy)
    );

    // Clock generator (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    // Task to check outputs
    task check_beat(
        input [ADDR_WIDTH-1:0]     exp_addr,
        input [BURST_LEN_BITS-1:0] exp_beat,
        input                      exp_last,
        input [127:0]              label
    );
    begin
        @(posedge clk);
        #1; // Sample post-clock edge
        if (current_addr !== exp_addr || current_beat !== exp_beat || is_last_beat !== exp_last) begin
            $display("[FAIL] %0s | Addr: 0x%08h (Exp: 0x%08h) | Beat: %0d (Exp: %0d) | Last: %b (Exp: %b)",
                     label, current_addr, exp_addr, current_beat, exp_beat, is_last_beat, exp_last);
            $finish;
        end else begin
            $display("[PASS] %0s | Addr: 0x%08h | Beat: %0d | Last: %b",
                     label, current_addr, current_beat, is_last_beat);
        end
    end
    endtask

    initial begin
        // Initialize inputs
        clk         = 0;
        aresetn     = 0;
        burst_start = 0;
        beat_ack    = 0;
        init_addr   = 0;
        burst_len   = 0;
        burst_type  = 0;

        // Reset sequence
        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting burst_controller Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Single Transfer (len = 0, beat count = 1)
        // =========================================================
        $display("\n--- Running Test 1: Single Beat (len = 0) ---");
        @(posedge clk);
        burst_start = 1;
        init_addr   = 32'h0000_0020;
        burst_len   = 4'd0;
        burst_type  = 2'b01; // INCR
        check_beat(32'h0000_0020, 4'd0, 1'b1, "Test 1: Single beat");

        @(posedge clk);
        burst_start = 0;
        beat_ack    = 1;
        #1;
        beat_ack    = 0;

        // =========================================================
        // TEST 2: 4-Beat INCR Burst (0x10, 0x14, 0x18, 0x1C)
        // =========================================================
        $display("\n--- Running Test 2: 4-Beat INCR Burst ---");
        @(posedge clk);
        burst_start = 1;
        init_addr   = 32'h0000_0010;
        burst_len   = 4'd3;  // 4 beats (0 to 3)
        burst_type  = 2'b01; // INCR
        check_beat(32'h0000_0010, 4'd0, 1'b0, "Test 2: Beat 0");

        burst_start = 0;
        beat_ack    = 1;
        check_beat(32'h0000_0014, 4'd1, 1'b0, "Test 2: Beat 1");
        check_beat(32'h0000_0018, 4'd2, 1'b0, "Test 2: Beat 2");
        check_beat(32'h0000_001C, 4'd3, 1'b1, "Test 2: Beat 3 (Last)");

        @(posedge clk);
        beat_ack = 0;

        // =========================================================
        // TEST 3: 4-Beat FIXED Burst (Addr stays 0x0000_0040)
        // =========================================================
        $display("\n--- Running Test 3: 4-Beat FIXED Burst ---");
        @(posedge clk);
        burst_start = 1;
        init_addr   = 32'h0000_0040;
        burst_len   = 4'd3;
        burst_type  = 2'b00; // FIXED
        check_beat(32'h0000_0040, 4'd0, 1'b0, "Test 3: Beat 0");

        burst_start = 0;
        beat_ack    = 1;
        check_beat(32'h0000_0040, 4'd1, 1'b0, "Test 3: Beat 1");
        check_beat(32'h0000_0040, 4'd2, 1'b0, "Test 3: Beat 2");
        check_beat(32'h0000_0040, 4'd3, 1'b1, "Test 3: Beat 3 (Last)");

        @(posedge clk);
        beat_ack = 0;

        // =========================================================
        // TEST 4: 4-Beat WRAP Burst (Start at 0x0C -> 16-byte boundary)
        // Sequence: 0x0C -> 0x00 -> 0x04 -> 0x08
        // =========================================================
        $display("\n--- Running Test 4: 4-Beat WRAP Burst ---");
        @(posedge clk);
        burst_start = 1;
        init_addr   = 32'h0000_000C; // Slot 3 of 16-byte boundary
        burst_len   = 4'd3;          // 4 beats = 16 bytes total
        burst_type  = 2'b10;         // WRAP
        check_beat(32'h0000_000C, 4'd0, 1'b0, "Test 4: Beat 0 (Start 0x0C)");

        burst_start = 0;
        beat_ack    = 1;
        check_beat(32'h0000_0000, 4'd1, 1'b0, "Test 4: Beat 1 (Wrap to 0x00)");
        check_beat(32'h0000_0004, 4'd2, 1'b0, "Test 4: Beat 2 (0x04)");
        check_beat(32'h0000_0008, 4'd3, 1'b1, "Test 4: Beat 3 (0x08 - Last)");

        @(posedge clk);
        beat_ack = 0;

        // =========================================================
        // TEST 5: Backpressure Stall (beat_ack deasserted mid-burst)
        // =========================================================
        $display("\n--- Running Test 5: Backpressure Mid-Burst ---");
        @(posedge clk);
        burst_start = 1;
        init_addr   = 32'h0000_0100;
        burst_len   = 4'd2; // 3 beats
        burst_type  = 2'b01;
        check_beat(32'h0000_0100, 4'd0, 1'b0, "Test 5: Beat 0");

        burst_start = 0;
        beat_ack    = 1;
        check_beat(32'h0000_0104, 4'd1, 1'b0, "Test 5: Beat 1");

        // Stall for 2 cycles (beat_ack = 0)
        beat_ack = 0;
        @(posedge clk);
        #1;
        if (current_addr !== 32'h0000_0104 || current_beat !== 4'd1) begin
            $display("[FAIL] Test 5: Address or beat changed during stall!");
            $finish;
        end else begin
            $display("[PASS] Test 5: Stalled cleanly at 0x%08h, beat %0d", current_addr, current_beat);
        end

        @(posedge clk);
        // Resume
        beat_ack = 1;
        check_beat(32'h0000_0108, 4'd2, 1'b1, "Test 5: Beat 2 (Last)");

        @(posedge clk);
        beat_ack = 0;

        $display("\n--------------------------------------------------");
        $display("ALL BURST CONTROLLER TESTS COMPLETED & VERIFIED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule