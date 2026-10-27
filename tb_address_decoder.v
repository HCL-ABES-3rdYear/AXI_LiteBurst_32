`timescale 1ns/1ps

module tb_address_decoder;

    parameter ADDR_WIDTH = 32;
    parameter MEM_BASE   = 32'h0000_0010;
    parameter MEM_SIZE   = 32'h0000_0400;

    reg  [ADDR_WIDTH-1:0] addr;
    reg                   addr_valid;
    wire                  sel_ctrl;
    wire                  sel_status;
    wire                  sel_config;
    wire                  sel_mem;
    wire                  dec_err;

    // Instantiate Unit Under Test (UUT)
    address_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_BASE(MEM_BASE),
        .MEM_SIZE(MEM_SIZE)
    ) uut (
        .addr(addr),
        .addr_valid(addr_valid),
        .sel_ctrl(sel_ctrl),
        .sel_status(sel_status),
        .sel_config(sel_config),
        .sel_mem(sel_mem),
        .dec_err(dec_err)
    );

    // Test verification task
    task check_output(
        input exp_ctrl,
        input exp_status,
        input exp_config,
        input exp_mem,
        input exp_err,
        input [127:0] test_name
    );
    begin
        #5; // Wait for combinational logic to settle
        if ((sel_ctrl   === exp_ctrl)   &&
            (sel_status === exp_status) &&
            (sel_config === exp_config) &&
            (sel_mem    === exp_mem)    &&
            (dec_err    === exp_err)) begin
            $display("[PASS] %0s | Addr: 0x%08h", test_name, addr);
        end else begin
            $display("[FAIL] %0s | Addr: 0x%08h | Expected: {c=%b,s=%b,cfg=%b,m=%b,err=%b} | Got: {c=%b,s=%b,cfg=%b,m=%b,err=%b}",
                     test_name, addr, exp_ctrl, exp_status, exp_config, exp_mem, exp_err,
                     sel_ctrl, sel_status, sel_config, sel_mem, dec_err);
            $finish;
        end
    end
    endtask

    initial begin
        $display("--------------------------------------------------");
        $display("Starting address_decoder Verification...");
        $display("--------------------------------------------------");

        addr = 32'h0;
        addr_valid = 1'b0;
        #10;

        // Test 1: Inactive valid strobe (All outputs must be 0)
        addr = 32'h0000_0000;
        addr_valid = 1'b0;
        check_output(0, 0, 0, 0, 0, "TEST 1: Inactive Valid");

        // Test 2: CTRL Register (0x0000_0000)
        addr_valid = 1'b1;
        addr = 32'h0000_0000;
        check_output(1, 0, 0, 0, 0, "TEST 2: CTRL Reg");

        // Test 3: STATUS Register (0x0000_0004)
        addr = 32'h0000_0004;
        check_output(0, 1, 0, 0, 0, "TEST 3: STATUS Reg");

        // Test 4: CONFIG Register (0x0000_0008)
        addr = 32'h0000_0008;
        check_output(0, 0, 1, 0, 0, "TEST 4: CONFIG Reg");

        // Test 5: Address Hole (0x0000_000C) -> Must give DECERR
        addr = 32'h0000_000C;
        check_output(0, 0, 0, 0, 1, "TEST 5: Hole 0x0C");

        // Test 6: Memory Base start (0x0000_0010)
        addr = 32'h0000_0010;
        check_output(0, 0, 0, 1, 0, "TEST 6: Memory Start");

        // Test 7: Memory Mid point (0x0000_0100)
        addr = 32'h0000_0100;
        check_output(0, 0, 0, 1, 0, "TEST 7: Memory Mid");

        // Test 8: Memory Upper Boundary (0x0000_040F)
        addr = MEM_BASE + MEM_SIZE - 1;
        check_output(0, 0, 0, 1, 0, "TEST 8: Memory End");

        // Test 9: Out of Bounds Address (0x0000_0410) -> Must give DECERR
        addr = MEM_BASE + MEM_SIZE;
        check_output(0, 0, 0, 0, 1, "TEST 9: OOB Higher");

        // Test 10: Completely Wild Unmapped Address (0xDEAD_BEEF)
        addr = 32'hDEAD_BEEF;
        check_output(0, 0, 0, 0, 1, "TEST 10: Unmapped Addr");

        $display("--------------------------------------------------");
        $display("ALL 10 VERIFICATION TESTS PASSED SUCCESSFULLY!");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule