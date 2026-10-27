`timescale 1ns/1ps

module tb_read_data_path;

    parameter DATA_WIDTH = 32;

    reg                   clk;
    reg                   aresetn;
    reg                   rd_en;
    reg                   sel_ctrl;
    reg                   sel_status;
    reg                   sel_config;
    reg                   sel_mem;
    reg                   dec_err;
    reg  [DATA_WIDTH-1:0] reg_ctrl_data;
    reg  [DATA_WIDTH-1:0] reg_status_data;
    reg  [DATA_WIDTH-1:0] reg_config_data;
    reg  [DATA_WIDTH-1:0] mem_rdata;

    wire [DATA_WIDTH-1:0] staged_rdata;
    wire                  rdata_valid;

    // Instantiate Unit Under Test (UUT)
    read_data_path #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .rd_en(rd_en),
        .sel_ctrl(sel_ctrl),
        .sel_status(sel_status),
        .sel_config(sel_config),
        .sel_mem(sel_mem),
        .dec_err(dec_err),
        .reg_ctrl_data(reg_ctrl_data),
        .reg_status_data(reg_status_data),
        .reg_config_data(reg_config_data),
        .mem_rdata(mem_rdata),
        .staged_rdata(staged_rdata),
        .rdata_valid(rdata_valid)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk             = 0;
        aresetn         = 0;
        rd_en           = 0;
        sel_ctrl        = 0;
        sel_status      = 0;
        sel_config      = 0;
        sel_mem         = 0;
        dec_err         = 0;
        reg_ctrl_data   = 32'hC001_0001;
        reg_status_data = 32'h57A7_0002;
        reg_config_data = 32'hC01F_0003;
        mem_rdata       = 32'hBEEF_CAFE;

        #20;
        aresetn = 1;
        #10;

        $display("--------------------------------------------------");
        $display("Starting read_data_path Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Read CTRL Register (0x00)
        // =========================================================
        @(posedge clk);
        sel_ctrl = 1;
        rd_en    = 1;

        @(posedge clk);
        #1;
        sel_ctrl = 0;
        rd_en    = 0;
        if (rdata_valid && (staged_rdata === 32'hC001_0001)) begin
            $display("[PASS] TEST 1: Staged CTRL register data (0x%08h).", staged_rdata);
        end else begin
            $display("[FAIL] TEST 1: Expected 0xC0010001, got 0x%08h", staged_rdata);
            $finish;
        end

        // =========================================================
        // TEST 2: Read STATUS Register (0x04)
        // =========================================================
        @(posedge clk);
        sel_status = 1;
        rd_en      = 1;

        @(posedge clk);
        #1;
        sel_status = 0;
        rd_en      = 0;
        if (rdata_valid && (staged_rdata === 32'h57A7_0002)) begin
            $display("[PASS] TEST 2: Staged STATUS register data (0x%08h).", staged_rdata);
        end else begin
            $display("[FAIL] TEST 2: Expected 0x57A70002, got 0x%08h", staged_rdata);
            $finish;
        end

        // =========================================================
        // TEST 3: Read Memory Data
        // =========================================================
        @(posedge clk);
        sel_mem = 1;
        rd_en   = 1;

        @(posedge clk);
        #1;
        sel_mem = 0;
        rd_en   = 0;
        if (rdata_valid && (staged_rdata === 32'hBEEF_CAFE)) begin
            $display("[PASS] TEST 3: Staged Memory array data (0x%08h).", staged_rdata);
        end else begin
            $display("[FAIL] TEST 3: Expected 0xBEEFCAFE, got 0x%08h", staged_rdata);
            $finish;
        end

        // =========================================================
        // TEST 4: Decode Error Read -> Zero Tie-off
        // =========================================================
        @(posedge clk);
        dec_err = 1;
        rd_en   = 1;

        @(posedge clk);
        #1;
        dec_err = 0;
        rd_en   = 0;
        if (rdata_valid && (staged_rdata === 32'h0000_0000)) begin
            $display("[PASS] TEST 4: Decode error zero data vector verified.");
        end else begin
            $display("[FAIL] TEST 4: Staged non-zero data on decode error!");
            $finish;
        end

        $display("--------------------------------------------------");
        $display("ALL 4 READ DATA PATH TESTS PASSED!");
        $display("--------------------------------------------------");
        #20;
        $finish;
    end

endmodule