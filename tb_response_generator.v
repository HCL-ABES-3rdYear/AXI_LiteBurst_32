`timescale 1ns/1ps

module tb_response_generator;

    reg        dec_err;
    reg        wr_prot_err;
    wire [1:0] resp_out;

    // Instantiate Unit Under Test (UUT)
    response_generator uut (
        .dec_err(dec_err),
        .wr_prot_err(wr_prot_err),
        .resp_out(resp_out)
    );

    // Expected encodings
    localparam [1:0] EXP_OKAY   = 2'b00;
    localparam [1:0] EXP_SLVERR = 2'b10;
    localparam [1:0] EXP_DECERR = 2'b11;

    task verify_case(
        input [1:0]   expected_resp,
        input [127:0] test_name
    );
    begin
        #5; // Wait for combinational logic to settle
        if (resp_out === expected_resp) begin
            $display("[PASS] %0s | dec_err=%b, wr_prot_err=%b -> resp_out=2'b%02b",
                     test_name, dec_err, wr_prot_err, resp_out);
        end else begin
            $display("[FAIL] %0s | dec_err=%b, wr_prot_err=%b | Expected: 2'b%02b, Got: 2'b%02b",
                     test_name, dec_err, wr_prot_err, expected_resp, resp_out);
            $finish;
        end
    end
    endtask

    initial begin
        $display("--------------------------------------------------");
        $display("Starting response_generator Verification...");
        $display("--------------------------------------------------");

        // Test 1: Normal access (no errors) -> OKAY
        dec_err     = 1'b0;
        wr_prot_err = 1'b0;
        verify_case(EXP_OKAY, "TEST 1: Normal Access (OKAY)");

        // Test 2: Write protection error -> SLVERR
        dec_err     = 1'b0;
        wr_prot_err = 1'b1;
        verify_case(EXP_SLVERR, "TEST 2: Write Protection Error (SLVERR)");

        // Test 3: Decode error -> DECERR
        dec_err     = 1'b1;
        wr_prot_err = 1'b0;
        verify_case(EXP_DECERR, "TEST 3: Decode Error (DECERR)");

        // Test 4: Both errors asserted -> DECERR priority must win
        dec_err     = 1'b1;
        wr_prot_err = 1'b1;
        verify_case(EXP_DECERR, "TEST 4: Priority Check (DECERR over SLVERR)");

        $display("--------------------------------------------------");
        $display("ALL 4 RESPONSE TESTS PASSED SUCCESSFULLY!");
        $display("--------------------------------------------------");
        #10;
        $finish;
    end

endmodule