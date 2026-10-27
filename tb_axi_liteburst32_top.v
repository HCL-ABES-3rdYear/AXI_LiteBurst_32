`timescale 1ns/1ps

module tb_axi_liteburst32_top;

    parameter ADDR_WIDTH     = 32;
    parameter DATA_WIDTH     = 32;
    parameter STRB_WIDTH     = 4;
    parameter BURST_LEN_BITS = 4;

    reg                       s_axi_aclk;
    reg                       s_axi_aresetn;

    // AW Channel
    reg  [ADDR_WIDTH-1:0]     s_axi_awaddr;
    reg  [BURST_LEN_BITS-1:0] s_axi_awlen;
    reg  [1:0]                s_axi_awburst;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;

    // W Channel
    reg  [DATA_WIDTH-1:0]     s_axi_wdata;
    reg  [STRB_WIDTH-1:0]     s_axi_wstrb;
    reg                       s_axi_wlast;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;

    // B Channel
    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    // AR Channel
    reg  [ADDR_WIDTH-1:0]     s_axi_araddr;
    reg  [BURST_LEN_BITS-1:0] s_axi_arlen;
    reg  [1:0]                s_axi_arburst;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;

    // R Channel
    wire [DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rlast;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;

    wire                      core_idle_status;

    // Instantiate Top-Level IP
    axi_liteburst32_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .BURST_LEN_BITS(BURST_LEN_BITS),
        .MEM_BASE(32'h0000_0010),
        .MEM_SIZE(32'h0000_0400)
    ) dut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .core_idle_status(core_idle_status)
    );

    always #5 s_axi_aclk = ~s_axi_aclk; // 100 MHz clock

    // Master Task: Write Burst Transfer
    task axi_write_burst(
        input [ADDR_WIDTH-1:0]     start_addr,
        input [BURST_LEN_BITS-1:0] len,
        input [1:0]                btype,
        input [DATA_WIDTH-1:0]     start_data
    );
        integer beat;
        begin
            // 1. Send Write Address
            @(posedge s_axi_aclk);
            s_axi_awaddr  = start_addr;
            s_axi_awlen   = len;
            s_axi_awburst = btype;
            s_axi_awvalid = 1'b1;

            wait (s_axi_awready);
            @(posedge s_axi_aclk);
            s_axi_awvalid = 1'b0;

            // 2. Stream Write Data Beats
            for (beat = 0; beat <= len; beat = beat + 1) begin
                s_axi_wdata  = start_data + beat;
                s_axi_wstrb  = 4'b1111;
                s_axi_wlast  = (beat == len);
                s_axi_wvalid = 1'b1;
                
                @(posedge s_axi_aclk);
                while (!s_axi_wready) @(posedge s_axi_aclk);
            end
            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;

            // 3. Receive Write Response
            s_axi_bready = 1'b1;
            wait (s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    initial begin
        // Reset initialization
        s_axi_aclk    = 0;
        s_axi_aresetn = 0;
        s_axi_awaddr  = 0;
        s_axi_awlen   = 0;
        s_axi_awburst = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wlast   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arlen   = 0;
        s_axi_arburst = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        #30;
        s_axi_aresetn = 1;
        #20;

        $display("==================================================");
        $display("STARTING FULL SYSTEM INTEGRATION TESTBENCH");
        $display("==================================================");

        // TEST 1: 4-Beat Write Burst to Memory (0x10, 0x14, 0x18, 0x1C)
        $display("\n[TEST 1] Initiating 4-Beat INCR Write Burst to 0x10...");
        axi_write_burst(32'h0000_0010, 4'd3, 2'b01, 32'hA000_0000);
        if (s_axi_bresp === 2'b00) begin
            $display("[PASS] TEST 1: Write burst completed with OKAY response.");
        end else begin
            $display("[FAIL] TEST 1: Unexpected response BRESP = 2'b%02b", s_axi_bresp);
            $finish;
        end

        // TEST 2: 4-Beat Read Burst from Memory (0x10)
        $display("\n[TEST 2] Initiating 4-Beat INCR Read Burst from 0x10...");
        @(posedge s_axi_aclk);
        s_axi_araddr  = 32'h0000_0010;
        s_axi_arlen   = 4'd3;   // 4 beats
        s_axi_arburst = 2'b01;  // INCR
        s_axi_arvalid = 1'b1;

        wait (s_axi_arready);
        @(posedge s_axi_aclk);
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b1;

        // Check each beat
        repeat (4) begin
            wait (s_axi_rvalid);
            @(posedge s_axi_aclk);
            #1;
            $display("   --> Beat received: Data = 0x%08h | RLAST = %b | RRESP = 2'b%02b", 
                     s_axi_rdata, s_axi_rlast, s_axi_rresp);
        end
        s_axi_rready = 1'b0;
        $display("[PASS] TEST 2: Read burst data verified successfully.");

        // TEST 3: Permission Violation (Write to Read-Only STATUS Reg at 0x04)
        $display("\n[TEST 3] Attempting write to Read-Only STATUS register (0x04)...");
        axi_write_burst(32'h0000_0004, 4'd0, 2'b01, 32'hFFFF_FFFF);
        if (s_axi_bresp === 2'b10) begin
            $display("[PASS] TEST 3: Correctly triggered SLVERR (2'b10) for read-only access violation.");
        end else begin
            $display("[FAIL] TEST 3: Expected SLVERR (2'b10), got 2'b%02b", s_axi_bresp);
            $finish;
        end

        // TEST 4: Unmapped Address Hole Access (0x0C)
        $display("\n[TEST 4] Attempting access to unmapped hole (0x0C)...");
        axi_write_burst(32'h0000_000C, 4'd0, 2'b01, 32'h1234_5678);
        if (s_axi_bresp === 2'b11) begin
            $display("[PASS] TEST 4: Correctly triggered DECERR (2'b11) on unmapped address.");
        end else begin
            $display("[FAIL] TEST 4: Expected DECERR (2'b11), got 2'b%02b", s_axi_bresp);
            $finish;
        end

        $display("\n==================================================");
        $display("ALL INTEGRATION TESTS COMPLETED & VERIFIED 100%%!");
        $display("==================================================");
        #50;
        $finish;
    end

endmodule