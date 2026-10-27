`timescale 1ns/1ps

module tb_write_data_path;

    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = DATA_WIDTH / 8;

    reg                  clk;
    reg                  aresetn;
    reg                  wr_en;
    reg                  sel_ctrl;
    reg                  sel_status;
    reg                  sel_config;
    reg                  sel_mem;
    reg [DATA_WIDTH-1:0] wdata;
    reg [STRB_WIDTH-1:0] wstrb;
    reg [DATA_WIDTH-1:0] orig_data;

    wire [DATA_WIDTH-1:0] masked_wdata;
    wire                  ctrl_we;
    wire                  config_we;
    wire [STRB_WIDTH-1:0] mem_we;
    wire                  wr_prot_err;

    write_data_path #(
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .wr_en(wr_en),
        .sel_ctrl(sel_ctrl),
        .sel_status(sel_status),
        .sel_config(sel_config),
        .sel_mem(sel_mem),
        .wdata(wdata),
        .wstrb(wstrb),
        .orig_data(orig_data),
        .masked_wdata(masked_wdata),
        .ctrl_we(ctrl_we),
        .config_we(config_we),
        .mem_we(mem_we),
        .wr_prot_err(wr_prot_err)
    );

    initial begin
        clk         = 0;
        aresetn     = 1;
        wr_en       = 0;
        sel_ctrl    = 0;
        sel_status  = 0;
        sel_config  = 0;
        sel_mem     = 0;
        wdata       = 32'h0;
        wstrb       = 4'h0;
        orig_data   = 32'hAAAA_AAAA;

        #10;
        $display("--------------------------------------------------");
        $display("Starting write_data_path Verification...");
        $display("--------------------------------------------------");

        // =========================================================
        // TEST 1: Byte-enable masking (wstrb = 4'b0001 -> update only Byte 0)
        // orig_data = 0xAAAAAAAA, wdata = 0x112233FF
        // Expected result = 0xAAAAAAFF
        // =========================================================
        wdata = 32'h1122_33FF;
        wstrb = 4'b0001;
        #5;
        if (masked_wdata === 32'hAAAA_AAFF) begin
            $display("[PASS] TEST 1: Strobe 4'b0001 masked data successfully (0x%08h).", masked_wdata);
        end else begin
            $display("[FAIL] TEST 1: Expected 0xAAAAAAFF, got 0x%08h", masked_wdata);
            $finish;
        end

        // =========================================================
        // TEST 2: Mid 2 Bytes masking (wstrb = 4'b0110)
        // orig_data = 0xAAAAAAAA, wdata = 0x0055_6600
        // Expected result = 0xAA55_66AA
        // =========================================================
        wdata = 32'h0055_6600;
        wstrb = 4'b0110;
        #5;
        if (masked_wdata === 32'hAA55_66AA) begin
            $display("[PASS] TEST 2: Strobe 4'b0110 masked data successfully (0x%08h).", masked_wdata);
        end else begin
            $display("[FAIL] TEST 2: Expected 0xAA5566AA, got 0x%08h", masked_wdata);
            $finish;
        end

        // =========================================================
        // TEST 3: Write to Read-Only STATUS Register
        // Must assert wr_prot_err without enabling any register writes
        // =========================================================
        wr_en      = 1'b1;
        sel_status = 1'b1;
        #5;
        if (wr_prot_err && !ctrl_we && !config_we && mem_we == 4'b0000) begin
            $display("[PASS] TEST 3: Write protection violation detected on STATUS reg.");
        end else begin
            $display("[FAIL] TEST 3: Write protection failed to flag!");
            $finish;
        end

        // =========================================================
        // TEST 4: Valid Write to Memory
        // =========================================================
        sel_status = 1'b0;
        sel_mem    = 1'b1;
        wstrb      = 4'b1111;
        #5;
        if (!wr_prot_err && mem_we === 4'b1111) begin
            $display("[PASS] TEST 4: Memory byte enables driven cleanly.");
        end else begin
            $display("[FAIL] TEST 4: Memory write routing failed!");
            $finish;
        end

        $display("--------------------------------------------------");
        $display("ALL 4 WRITE DATA PATH TESTS PASSED!");
        $display("--------------------------------------------------");
        #10;
        $finish;
    end

endmodule