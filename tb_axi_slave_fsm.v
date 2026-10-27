`timescale 1ns/1ps

module tb_axi_slave_fsm;

    // Clock and Reset
    reg clk;
    reg aresetn;

    // Handshake stimulus inputs
    reg aw_handshake_done;
    reg ar_handshake_done;
    reg w_beat_ack;
    reg is_last_write_beat;
    reg r_beat_ack;
    reg is_last_read_beat;
    reg b_handshake_done;

    // DUT output monitor wires
    wire burst_start_wr;
    wire burst_start_rd;
    wire wr_en;
    wire rd_en;
    wire wr_complete_pulse;
    wire fsm_busy;
    wire aw_fifo_full;
    wire ar_pipe_busy;

    // Instantiate Unit Under Test (UUT)
    axi_slave_fsm uut (
        .clk(clk),
        .aresetn(aresetn),
        .aw_handshake_done(aw_handshake_done),
        .ar_handshake_done(ar_handshake_done),
        .w_beat_ack(w_beat_ack),
        .is_last_write_beat(is_last_write_beat),
        .r_beat_ack(r_beat_ack),
        .is_last_read_beat(is_last_read_beat),
        .b_handshake_done(b_handshake_done),
        .burst_start_wr(burst_start_wr),
        .burst_start_rd(burst_start_rd),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_complete_pulse(wr_complete_pulse),
        .fsm_busy(fsm_busy),
        .aw_fifo_full(aw_fifo_full),
        .ar_pipe_busy(ar_pipe_busy)
    );

    // 100 MHz clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize all inputs
        clk                = 0;
        aresetn            = 0;
        aw_handshake_done  = 0;
        ar_handshake_done  = 0;
        w_beat_ack         = 0;
        is_last_write_beat = 0;
        r_beat_ack         = 0;
        is_last_read_beat  = 0;
        b_handshake_done   = 0;

        // Apply Reset
        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting axi_slave_fsm Unit Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Initial Idle State Check
        // =========================================================
        @(posedge clk);
        #1;
        if (!fsm_busy && !aw_fifo_full && !ar_pipe_busy) begin
            $display("[PASS] TEST 1: FSM initializes cleanly in S_IDLE.");
        end else begin
            $display("[FAIL] TEST 1: Unexpected active flags in idle state!");
            $finish;
        end

        // =========================================================
        // TEST 2: Complete Write Burst Sequence (IDLE -> WR_BURST -> WR_RESP -> IDLE)
        // =========================================================
        $display("\n--- Testing Write Flow ---");
        @(posedge clk);
        aw_handshake_done = 1'b1;

        @(posedge clk);
        #1;
        aw_handshake_done = 1'b0;
        if (fsm_busy && aw_fifo_full && ar_pipe_busy) begin
            $display("[PASS] TEST 2a: Transitioned to S_WR_BURST (channels locked).");
        end else begin
            $display("[FAIL] TEST 2a: Did not transition to S_WR_BURST!");
            $finish;
        end

        // Intermediate write beat
        w_beat_ack         = 1'b1;
        is_last_write_beat = 1'b0;
        #1;
        if (wr_en && !wr_complete_pulse) begin
            $display("[PASS] TEST 2b: Intermediate beat asserts wr_en without completion pulse.");
        end else begin
            $display("[FAIL] TEST 2b: wr_en / wr_complete_pulse mismatch!");
            $finish;
        end

        // Final write beat
        @(posedge clk);
        w_beat_ack         = 1'b1;
        is_last_write_beat = 1'b1;
        #1;
        if (wr_en && wr_complete_pulse) begin
            $display("[PASS] TEST 2c: Final beat triggers wr_complete_pulse.");
        end else begin
            $display("[FAIL] TEST 2c: wr_complete_pulse failed on final beat!");
            $finish;
        end

        // Move to S_WR_RESP
        @(posedge clk);
        w_beat_ack         = 1'b0;
        is_last_write_beat = 1'b0;
        #1;
        if (fsm_busy && !wr_en) begin
            $display("[PASS] TEST 2d: In S_WR_RESP waiting for B-channel handshake.");
        end else begin
            $display("[FAIL] TEST 2d: Failed to enter S_WR_RESP!");
            $finish;
        end

        // Complete response handshake
        @(posedge clk);
        b_handshake_done = 1'b1;
        @(posedge clk);
        #1;
        b_handshake_done = 1'b0;
        if (!fsm_busy) begin
            $display("[PASS] TEST 2e: Returned to S_IDLE after b_handshake_done.");
        end else begin
            $display("[FAIL] TEST 2e: FSM failed to return to IDLE!");
            $finish;
        end

        // =========================================================
        // TEST 3: Complete Read Burst Sequence (IDLE -> RD_PIPE -> RD_BURST -> IDLE)
        // =========================================================
        $display("\n--- Testing Read Flow ---");
        @(posedge clk);
        ar_handshake_done = 1'b1;

        @(posedge clk);
        #1;
        ar_handshake_done = 1'b0;
        if (rd_en && fsm_busy) begin
            $display("[PASS] TEST 3a: Entered S_RD_PIPE and asserted rd_en memory fetch.");
        end else begin
            $display("[FAIL] TEST 3a: Failed to enter S_RD_PIPE!");
            $finish;
        end

        // Advance from pipe stage to burst beat output
        @(posedge clk);
        #1;
        if (!rd_en && fsm_busy) begin
            $display("[PASS] TEST 3b: Entered S_RD_BURST waiting for master RREADY.");
        end else begin
            $display("[FAIL] TEST 3b: Failed to enter S_RD_BURST!");
            $finish;
        end

        // Final read beat acknowledged
        r_beat_ack        = 1'b1;
        is_last_read_beat = 1'b1;
        @(posedge clk);
        #1;
        r_beat_ack        = 1'b0;
        is_last_read_beat = 1'b0;
        if (!fsm_busy) begin
            $display("[PASS] TEST 3c: Final read beat returned FSM back to S_IDLE.");
        end else begin
            $display("[FAIL] TEST 3c: FSM did not return to IDLE after last read beat!");
            $finish;
        end

        // =========================================================
        // TEST 4: Simultaneous AW & AR Collision (Priority Arbitration)
        // =========================================================
        $display("\n--- Testing Simultaneous Write & Read Collision ---");
        @(posedge clk);
        aw_handshake_done = 1'b1;
        ar_handshake_done = 1'b1;

        @(posedge clk);
        #1;
        aw_handshake_done = 1'b0;
        ar_handshake_done = 1'b0;
        // Must prioritize Write (enter S_WR_BURST with wr_en active on beat, not rd_en)
        if (fsm_busy && !rd_en) begin
            $display("[PASS] TEST 4: Write successfully prioritized over Read during collision.");
        end else begin
            $display("[FAIL] TEST 4: Read erroneously serviced over Write during simultaneous arrival!");
            $finish;
        end

        // Clean up state back to idle
        @(posedge clk);
        w_beat_ack         = 1'b1;
        is_last_write_beat = 1'b1;
        @(posedge clk);
        w_beat_ack         = 1'b0;
        is_last_write_beat = 1'b0;
        b_handshake_done   = 1'b1;
        @(posedge clk);
        b_handshake_done   = 1'b0;

        $display("\n--------------------------------------------------");
        $display("ALL 4 FSM UNIT TESTS PASSED SUCCESSFULLY!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule