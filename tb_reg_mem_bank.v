`timescale 1ns/1ps

module tb_reg_mem_bank;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = 4;
    parameter MEM_DEPTH  = 256;

    reg                   clk;
    reg                   aresetn;
    reg                   ctrl_we;
    reg                   config_we;
    reg  [STRB_WIDTH-1:0] mem_we;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg  [ADDR_WIDTH-1:0] wr_addr;
    reg  [ADDR_WIDTH-1:0] rd_addr;
    reg  [DATA_WIDTH-1:0] hw_status_in;

    wire [DATA_WIDTH-1:0] reg_ctrl_out;
    wire [DATA_WIDTH-1:0] reg_status_out;
    wire [DATA_WIDTH-1:0] reg_config_out;
    wire [DATA_WIDTH-1:0] mem_rdata_out;

    reg_mem_bank #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .ctrl_we(ctrl_we),
        .config_we(config_we),
        .mem_we(mem_we),
        .wr_data(wr_data),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr),
        .hw_status_in(hw_status_in),
        .reg_ctrl_out(reg_ctrl_out),
        .reg_status_out(reg_status_out),
        .reg_config_out(reg_config_out),
        .mem_rdata_out(mem_rdata_out)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk          = 0;
        aresetn      = 0;
        ctrl_we      = 0;
        config_we    = 0;
        mem_we       = 4'h0;
        wr_data      = 32'h0;
        wr_addr      = 32'h0;
        rd_addr      = 32'h0;
        hw_status_in = 32'h0;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting reg_mem_bank Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Control & Config Register Write/Read
        // =========================================================
        @(posedge clk);
        wr_data   = 32'h0000_0001; // Enable core
        ctrl_we   = 1'b1;
        @(posedge clk);
        ctrl_we   = 1'b0;
        wr_data   = 32'hA5A5_0010; // Prescaler configuration
        config_we = 1'b1;
        @(posedge clk);
        config_we = 1'b0;

        #1;
        if ((reg_ctrl_out === 32'h0000_0001) && (reg_config_out === 32'hA5A5_0010)) begin
            $display("[PASS] TEST 1: CTRL and CONFIG registers written and read back successfully.");
        end else begin
            $display("[FAIL] TEST 1: Register access failure!");
            $finish;
        end

        // =========================================================
        // TEST 2: STATUS Register Read-Only Hardware Reflection
        // =========================================================
        @(posedge clk);
        hw_status_in = 32'h5A5A_BEEF; // Injected by hardware logic
        #1;
        if (reg_status_out === 32'h5A5A_BEEF) begin
            $display("[PASS] TEST 2: STATUS register correctly mirrors internal hardware state.");
        end else begin
            $display("[FAIL] TEST 2: STATUS register mirror failed!");
            $finish;
        end

        // =========================================================
        // TEST 3: Memory Word Write and Synchronous Read
        // =========================================================
        @(posedge clk);
        wr_addr = 32'h0000_0014; // Index 1
        wr_data = 32'hCAFE_BABE;
        mem_we  = 4'b1111;
        @(posedge clk);
        mem_we  = 4'b0000;

        // Perform read from address 0x14
        rd_addr = 32'h0000_0014;
        @(posedge clk); // Memory clock cycle latency
        #1;
        if (mem_rdata_out === 32'hCAFE_BABE) begin
            $display("[PASS] TEST 3: Memory write and synchronous read-back verified.");
        end else begin
            $display("[FAIL] TEST 3: Expected 0xCAFEBABE, got 0x%08h", mem_rdata_out);
            $finish;
        end

        // =========================================================
        // TEST 4: Byte Enable Granular Write
        // Write only byte 1 to 0x14 (change CAFE_BABE -> CAFE_55BE)
        // =========================================================
        @(posedge clk);
        wr_addr = 32'h0000_0014;
        wr_data = 32'h0000_5500;
        mem_we  = 4'b0010; // Byte 1 enable
        @(posedge clk);
        mem_we  = 4'b0000;

        rd_addr = 32'h0000_0014;
        @(posedge clk);
        #1;
        if (mem_rdata_out === 32'hCAFE_55BE) begin
            $display("[PASS] TEST 4: Byte-selective write correctly modified memory word.");
        end else begin
            $display("[FAIL] TEST 4: Expected 0xCAFE55BE, got 0x%08h", mem_rdata_out);
            $finish;
        end

        $display("--------------------------------------------------");
        $display("ALL 4 REG_MEM_BANK TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule