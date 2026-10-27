`timescale 1ns/1ps

module tb_low_power_controller;

    parameter IDLE_TIMEOUT = 8;

    reg  clk;
    reg  aresetn;
    reg  awvalid;
    reg  wvalid;
    reg  arvalid;
    reg  b_busy;
    reg  r_busy;
    reg  fsm_busy;

    wire gated_clk;
    wire is_idle;

    low_power_controller #(
        .IDLE_TIMEOUT(IDLE_TIMEOUT)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .awvalid(awvalid),
        .wvalid(wvalid),
        .arvalid(arvalid),
        .b_busy(b_busy),
        .r_busy(r_busy),
        .fsm_busy(fsm_busy),
        .gated_clk(gated_clk),
        .is_idle(is_idle)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk      = 0;
        aresetn  = 0;
        awvalid  = 0;
        wvalid   = 0;
        arvalid  = 0;
        b_busy   = 0;
        r_busy   = 0;
        fsm_busy = 0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting low_power_controller Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Initial Awake State
        // =========================================================
        @(posedge clk);
        #1;
        if (!is_idle) begin
            $display("[PASS] TEST 1: Core initialized in active awake mode.");
        end else begin
            $display("[FAIL] TEST 1: Core entered idle immediately post-reset!");
            $finish;
        end

        // =========================================================
        // TEST 2: Idle Timeout Transition to Sleep
        // Wait IDLE_TIMEOUT cycles without activity
        // =========================================================
        repeat (IDLE_TIMEOUT + 2) @(posedge clk);
        #1;
        if (is_idle) begin
            $display("[PASS] TEST 2: Clock cleanly gated after %0d idle cycles.", IDLE_TIMEOUT);
        end else begin
            $display("[FAIL] TEST 2: Clock failed to gate after timeout!");
            $finish;
        end

        // Confirm gated_clk is frozen at 0 while main clk continues toggling
        repeat (4) @(posedge clk);
        #1;
        if (gated_clk === 1'b0) begin
            $display("[PASS] TEST 2: gated_clk remains static LOW during sleep.");
        end else begin
            $display("[FAIL] TEST 2: gated_clk toggled while in sleep mode!");
            $finish;
        end

        // =========================================================
        // TEST 3: Instant Wake-up on Incoming AWVALID
        // =========================================================
        @(negedge clk);
        awvalid = 1'b1; // Master starts write transaction

        #1;
        if (!is_idle) begin
            $display("[PASS] TEST 3: AWVALID triggered immediate wake-up from sleep.");
        end else begin
            $display("[FAIL] TEST 3: Wake-up override failed!");
            $finish;
        end

        @(posedge clk);
        #1;
        if (gated_clk === 1'b1) begin
            $display("[PASS] TEST 3: gated_clk toggles normally upon wake-up.");
        end else begin
            $display("[FAIL] TEST 3: Clock did not resume on posedge clk!");
            $finish;
        end

        awvalid = 1'b0;

        $display("--------------------------------------------------");
        $display("ALL 3 LOW-POWER CONTROLLER TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule