`timescale 1ns/1ps
//--------------------------------------------------------------------
//  Test‑bench :  tb_instruction_memory (debug version with clk/rst)
//--------------------------------------------------------------------
module tb_instruction_memory;

    //----------------------------------------------------------------
    //  Signals
    //----------------------------------------------------------------
    reg  [31:0] byte_addr = 32'h0;
    wire [9:0]  word_addr = byte_addr[11:2];
    wire [31:0] data;

    // Debug visibility signals
    reg clk = 0;
    reg rst = 1;  // not used by DUT, but shown in waveform

    //----------------------------------------------------------------
    //  Clock generation (10ns period)
    //----------------------------------------------------------------
    always #5 clk = ~clk;

    //----------------------------------------------------------------
    //  DUT instantiation
    //----------------------------------------------------------------
    instruction_memory #(
        .MEM_SIZE (1024),
        .INIT_FILE("")
    ) uut (
        .addr     (word_addr),
        .data_out (data)
    );

    //----------------------------------------------------------------
    //  Expected instruction table
    //----------------------------------------------------------------
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
            expected_instr[i] = 32'h00000013;
    end

    //----------------------------------------------------------------
    //  Book‑keeping
    //----------------------------------------------------------------
    integer errors     = 0;
    integer test_count = 0;

    //----------------------------------------------------------------
    //  Waveform dump – includes clk, rst, addr, data_out
    //----------------------------------------------------------------
    initial begin
        $dumpfile("tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);
    end

    //----------------------------------------------------------------
    //  Main stimulus
    //----------------------------------------------------------------
    initial begin
        // De-assert reset after a short delay
        #12 rst = 0;

        run_case(32'h000, expected_instr[0],  "Fetch Address 0  (ADD)"  );
        run_case(32'h004, expected_instr[1],  "Fetch Address 4  (ADDI)" );
        run_case(32'h008, expected_instr[2],  "Fetch Address 8  (LW)"   );
        run_case(32'h010, expected_instr[4],  "Fetch Address 16 (BEQ)"  );
        run_case(32'h018, expected_instr[6],  "Fetch Address 24 (JAL)"  );
        run_case(32'h020, expected_instr[8],  "Fetch Address 32 (JALR)" );
        run_case(32'h028, expected_instr[10], "Fetch Address 40 (AUIPC)");
        run_case(32'h02C, expected_instr[11], "Fetch Address 44 (NOP)"  );
        run_case(32'h0FC, expected_instr[63], "Fetch Address 252(NOP)"  );

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

    //----------------------------------------------------------------
    //  Helper tasks
    //----------------------------------------------------------------
    task run_case;
        input [31:0] addr_in_bytes;
        input [31:0] exp_data;
        input [8*50:1] case_name;
        begin
            byte_addr = addr_in_bytes;
            #10; // wait for data to stabilize
            $display("Running: %0s | addr=%08h | data=%08h",
                      case_name, byte_addr, data);
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
