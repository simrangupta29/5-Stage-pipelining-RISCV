`timescale 1ns/1ps

module tb_instruction_memory;

    // -------------------------------
    //  Clock and Reset
    // -------------------------------
    reg clk;
    reg rst;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    initial begin
        rst = 1;
        #12 rst = 0;
    end

    // -------------------------------
    //  DUT Interface Signals
    // -------------------------------
    reg  [31:0] byte_addr;          // byte address driven by TB
    wire [31:0] data;               // instruction word from memory
    wire [9:0]  word_addr = byte_addr[11:2];  // per-word addressing

    // -------------------------------
    //  Dummy ALU and Data Signals
    // -------------------------------
    reg  [31:0] alu_in1, alu_in2;
    wire [31:0] alu_result;

    assign alu_result = alu_in1 + alu_in2;

    reg  [31:0] data_in;
    wire [31:0] data_out;

    assign data_out = data;  // alias for waveform clarity

    // -------------------------------
    //  DUT Instance
    // -------------------------------
    instruction_memory #(
        .MEM_SIZE (1024),
        .INIT_FILE ("")  // empty => memory pre-filled with 0s
    ) uut (
        .addr     (word_addr),
        .data_out (data)
    );

    // -------------------------------
    //  Expected Instruction ROM
    // -------------------------------
    reg [31:0] expected_instr [0:63];
    integer i;

    initial begin
        expected_instr[0]  = 32'h005302b3;   // ADD
        expected_instr[1]  = 32'h00510293;   // ADDI
        expected_instr[2]  = 32'h0000a283;   // LW
        expected_instr[3]  = 32'h0050a223;   // SW
        expected_instr[4]  = 32'h00528463;   // BEQ
        expected_instr[5]  = 32'h00000013;   // NOP
        expected_instr[6]  = 32'h008000ef;   // JAL
        expected_instr[7]  = 32'h00000013;   // NOP
        expected_instr[8]  = 32'h000080e7;   // JALR
        expected_instr[9]  = 32'h000052b7;   // LUI
        expected_instr[10] = 32'h00005297;   // AUIPC
        for (i = 11; i < 64; i = i + 1)
            expected_instr[i] = 32'h00000013;  // fill remaining with NOP
    end

    // -------------------------------
    //  Test Summary
    // -------------------------------
    integer errors     = 0;
    integer test_count = 0;

    // -------------------------------
    //  Waveform Dump
    // -------------------------------
    initial begin
        $dumpfile("tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);
        $dumpvars(1, clk, rst);
        $dumpvars(1, byte_addr, word_addr, data, data_out);
        $dumpvars(1, alu_in1, alu_in2, alu_result, data_in);
    end

    // -------------------------------
    //  Main Test Sequence
    // -------------------------------
    initial begin
        // Initialize dummy signals
        alu_in1 = 32'h00000005;
        alu_in2 = 32'h0000000A;
        data_in = 32'hDEADBEEF;

        // Run instruction fetch test cases
        run_case(32'h000, expected_instr[0],  "Fetch Address 0  (ADD)"  );
        run_case(32'h004, expected_instr[1],  "Fetch Address 4  (ADDI)" );
        run_case(32'h008, expected_instr[2],  "Fetch Address 8  (LW)"   );
        run_case(32'h010, expected_instr[4],  "Fetch Address 16 (BEQ)"  );
        run_case(32'h018, expected_instr[6],  "Fetch Address 24 (JAL)"  );
        run_case(32'h020, expected_instr[8],  "Fetch Address 32 (JALR)" );
        run_case(32'h028, expected_instr[10], "Fetch Address 40 (AUIPC)");
        run_case(32'h02C, expected_instr[11], "Fetch Address 44 (NOP)"  );
        run_case(32'h0FC, expected_instr[63], "Fetch Address 252(NOP)"  );

        // Summary
        $display("\n--------------------------------------------------");
        $display("Test Summary: %0d tests run, %0d errors found",
                 test_count, errors);
        if (errors == 0)
            $display("All tests passed successfully!");
        else
            $display("Test failed with %0d errors.", errors);
        $display("--------------------------------------------------\n");
        $finish;
    end

    // -------------------------------
    //  Test Tasks
    // -------------------------------
    task run_case;
        input [31:0] addr_in_bytes;
        input [31:0] exp_data;
        input [8*50:1] case_name;
        begin
            $display("Running: %0s", case_name);
            byte_addr = addr_in_bytes;
            #10; // wait for memory read
            check_outputs(exp_data, case_name);
            test_count = test_count + 1;
        end
    endtask

    task check_outputs;
        input [31:0] exp;
        input [8*50:1] case_name;
        begin
            if (data !== exp) begin
                $display("ERROR in %0s: data = %h, expected = %h",
                         case_name, data, exp);
                errors = errors + 1;
            end
        end
    endtask

endmodule
