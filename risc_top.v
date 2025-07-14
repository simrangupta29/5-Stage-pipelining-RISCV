module fetch_stage (
    input         clk,
    input         reset,
    input         StallF,
    input         PCSrc,
    input  [31:0] PCTarget,
    output [31:0] imem_addr,
    output [31:0] pc_plus4
);
    reg [31:0] PC;
    always @(posedge clk or posedge reset) begin
        if (reset)
            PC <= 0;
        else if (!StallF)
            PC <= PCSrc ? PCTarget : PC + 4;
    end
    assign imem_addr = PC;
    assign pc_plus4 = PC + 4;
endmodule

// ============================================
// Module: IF/ID Register
// ============================================
module ifid_reg (
    input         clk,
    input         reset,
    input         FlushD,
    input         StallD,
    input  [31:0] pc_in,
    input  [31:0] pc_plus4_in,
    input  [31:0] instr_in,
    output reg [31:0] pc_plus4_out,
    output reg [31:0] instr_out,
    output reg [31:0] pc_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || FlushD) begin
            pc_plus4_out <= 0;
            instr_out    <= 0;
            pc_out       <= 0;
        end else if (!StallD) begin
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
            pc_out       <= pc_in;
        end
    end
endmodule



module instruction_memory
  #(parameter MEM_SIZE = 1024,
    parameter INIT_FILE = "")
(
    input  [9:0] addr,        // word address from core
    output [31:0] data_out
);
    reg [31:0] mem [0:MEM_SIZE-1];


    integer i;
    initial begin
        // Option‑1 : load from hex file if a name is given
        if (INIT_FILE != "") begin
            $display("Loading program from %0s …", INIT_FILE);
            $readmemh(INIT_FILE, mem);
        end
        // Option‑2 : otherwise hard‑wire the demo program
        else begin
            mem[0]  = 32'h005302b3; // ADD
            mem[1]  = 32'h00510293; // ADDI
            mem[2]  = 32'h0000a283; // LW
            mem[3]  = 32'h0050a223; // SW
            mem[4]  = 32'h00528463; // BEQ
            mem[5]  = 32'h00000013; // NOP
            mem[6]  = 32'h008000ef; // JAL
            mem[7]  = 32'h00000013; // NOP
            mem[8]  = 32'h000080e7; // JALR
            mem[9]  = 32'h000052b7; // LUI
            mem[10] = 32'h00005297; // AUIPC
            // Fill the rest with NOPs
            for (i = 11; i < MEM_SIZE; i = i + 1)
                mem[i] = 32'h00000013;
        end
    end
    assign data_out = mem[addr];

endmodule


// ================================================================
// decode_stage.v    –   RV32I decode + tiny register file
// ================================================================


module decode_stage (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instr,
    input  wire [31:0] pc,
    input  wire        RegWrite_wb,
    input  wire [4:0]  RD_wb,
    input  wire [31:0] ResultW,
    output reg         RegWriteE,
    output reg         MemWriteE,
    output reg         ALUSrcE,
    output reg         BranchE,
    output reg         JumpE,
    output reg [1:0]   ResultSrcE,
    output reg [2:0]   ALUControlE,
    output wire [31:0] RD1E,
    output wire [31:0] RD2E,
    output wire [31:0] ImmExtE,
    output wire [4:0]  RD_E,
    output wire [31:0] PCPlus4E,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [31:0] x4, x5, x6, x7, x9
);

    reg [31:0] regfile [0:31];
    integer k;
    initial begin
        for (k = 0; k < 32; k = k + 1)
            regfile[k] = k;
        regfile[1] = 1;   // x1
        regfile[2] = 2;   // x2
   	regfile[3] = 3;   // x3
    	regfile[4] = 4;   // x4
    	regfile[5] = 10;
    end

    assign x4 = regfile[4];
    assign x5 = regfile[5];
    assign x6 = regfile[6];
    assign x7 = regfile[7];
    assign x9 = regfile[9];

    always @(posedge clk) begin
        if (RegWrite_wb && RD_wb != 5'd0)
            regfile[RD_wb] <= ResultW;
        regfile[0] <= 32'b0;
    end

    assign rs1   = instr[19:15];
    assign rs2   = instr[24:20];
    assign RD_E  = instr[11:7];

    assign RD1E = (RegWrite_wb && (rs1 == RD_wb) && (RD_wb != 0)) ? ResultW : regfile[rs1];
    assign RD2E = (RegWrite_wb && (rs2 == RD_wb) && (RD_wb != 0)) ? ResultW : regfile[rs2];

    // Immediate Generation
    wire [6:0]  op        = instr[6:0];
    wire [2:0]  funct3    = instr[14:12];
    wire        funct7b5  = instr[30];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};

    assign ImmExtE = (op == 7'b0010011 || op == 7'b0000011 || op == 7'b1100111) ? imm_i :
                     (op == 7'b0100011) ? imm_s :
                     (op == 7'b1100011) ? imm_b :
                     (op == 7'b1101111) ? imm_j :
                     (op == 7'b0010111 || op == 7'b0110111) ? imm_u :
                     32'b0;

    assign PCPlus4E = pc + 32'd4;

    always @(*) begin
        RegWriteE   = 1'b0;
        MemWriteE   = 1'b0;
        ALUSrcE     = 1'b0;
        BranchE     = 1'b0;
        JumpE       = 1'b0;
        ResultSrcE  = 2'b00;
        ALUControlE = 3'b000;

        case (op)
            7'b0110011: begin // R-type
                RegWriteE = 1;
                ALUSrcE   = 0;
                case ({funct7b5, funct3})
                    4'b0_000: ALUControlE = 3'b000; // ADD
                    4'b1_000: ALUControlE = 3'b001; // SUB
                    4'b0_111: ALUControlE = 3'b010; // AND
                    4'b0_110: ALUControlE = 3'b011; // OR
                    default:  ALUControlE = 3'b000;
                endcase
            end
            7'b0010011: begin // I-type
                RegWriteE   = 1;
                ALUSrcE     = 1;
                ALUControlE = 3'b000; // ADDI
            end
            7'b0000011: begin // LW
                RegWriteE   = 1;
                ALUSrcE     = 1;
                ResultSrcE  = 2'b01;
                ALUControlE = 3'b000;
            end
            7'b0100011: begin // SW
                MemWriteE   = 1;
                ALUSrcE     = 1;
                ALUControlE = 3'b000;
            end
            7'b1100011: begin // BEQ
                BranchE     = 1;
                ALUControlE = 3'b001; // SUB
            end
            7'b1101111: begin // JAL
                RegWriteE   = 1;
                JumpE       = 1;
                ResultSrcE  = 2'b10;
            end
            7'b1100111: begin // JALR
                RegWriteE   = 1;
                JumpE       = 1;
                ALUSrcE     = 1;
                ResultSrcE  = 2'b10;
                ALUControlE = 3'b000;
            end
        endcase
    end

endmodule

module execute_cycle (
    input         clk, 
    input         rst,
    // Control Signals from Decode Stage
    input         RegWriteE, 
    input         ALUSrcE, 
    input         MemWriteE, 
    input  [1:0]  ResultSrcE,
    input         BranchE, 
    input         JumpE,
    input  [2:0]  ALUControlE,
    // Data Inputs
    input  [31:0] RD1_E, 
    input  [31:0] RD2_E, 
    input  [31:0] ImmExtE,
    input  [4:0]  RD_E,
    input  [31:0] PCE, 
    input  [31:0] PCPlus4E,
    input  [31:0] ResultW,
    input  [1:0]  ForwardA_E, 
    input  [1:0]  ForwardB_E,
    input  [4:0]  rs1_e_in,
    input  [4:0]  rs2_e_in,
    // Outputs to Fetch and Memory Stages
    output        PCSrcE,
    output        RegWriteM, 
    output        MemWriteM,
    output [1:0]  ResultSrcM,
    output [4:0]  RD_M,
    output [31:0] PCPlus4M, 
    output [31:0] WriteDataM,
    output [31:0] ALU_ResultM,
    output [31:0] PCTargetE,
    output [4:0]  rs1_e_out,
    output [4:0]  rs2_e_out
);
    wire [31:0] Src_AE, Src_B_selected, Src_BE;
    wire [31:0] ALUResultE;
    wire ZeroE, BranchTaken;
    Mux3to1 srcA_mux (
        .a(RD1_E),
        .b(ResultW),
        .c(ALU_ResultM),
        .s(ForwardA_E),
        .d(Src_AE)
    );
    
    Mux3to1 srcB_mux (
        .a(RD2_E),
        .b(ResultW),
        .c(ALU_ResultM),
        .s(ForwardB_E),
        .d(Src_B_selected)
    );
    
    Mux2to1 alu_src_mux (
        .a(Src_B_selected),
        .b(ImmExtE),
        .s(ALUSrcE),
        .c(Src_BE)
    );
    
    ALU alu (
        .A(Src_AE),
        .B(Src_BE),
        .ALUResult(ALUResultE),
        .ALUControl(ALUControlE),
        .OverFlow(),
        .Carry(),
        .Zero(ZeroE),
        .Negative()
    );
    
    PCAdder Branch_adder (
        .a(PCE),
        .b(ImmExtE),
        .c(PCTargetE)
    );
    
    assign BranchTaken = BranchE & ZeroE;
    assign PCSrcE = BranchTaken | JumpE;
    reg        RegWriteM_reg; 
    reg        MemWriteM_reg;
    reg [1:0]  ResultSrcM_reg;
    reg [4:0]  RD_M_reg;
    reg [31:0] PCPlus4M_reg; 
    reg [31:0] WriteDataM_reg;
    reg [31:0] ALU_ResultM_reg;
    reg [4:0]  rs1_e_out_reg;
    reg [4:0]  rs2_e_out_reg;
    assign RegWriteM   = RegWriteM_reg;
    assign MemWriteM   = MemWriteM_reg;
    assign ResultSrcM  = ResultSrcM_reg;
    assign RD_M        = RD_M_reg;
    assign PCPlus4M    = PCPlus4M_reg;
    assign WriteDataM  = WriteDataM_reg;
    assign ALU_ResultM = ALU_ResultM_reg;
    assign rs1_e_out   = rs1_e_out_reg;
    assign rs2_e_out   = rs2_e_out_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteM_reg   <= 1'b0;
            MemWriteM_reg   <= 1'b0;
            ResultSrcM_reg  <= 2'b00;
            RD_M_reg        <= 5'b00000;
            PCPlus4M_reg    <= 32'h00000000;
            WriteDataM_reg  <= 32'h00000000;
            ALU_ResultM_reg <= 32'h00000000;
            rs1_e_out_reg   <= 5'b0;
            rs2_e_out_reg   <= 5'b0;
        end else begin
            RegWriteM_reg   <= RegWriteE;
            MemWriteM_reg   <= MemWriteE;
            ResultSrcM_reg  <= ResultSrcE;
            RD_M_reg        <= RD_E;
            PCPlus4M_reg    <= PCPlus4E;
            WriteDataM_reg  <= Src_B_selected;
            ALU_ResultM_reg <= ALUResultE;
            rs1_e_out_reg   <= rs1_e_in;
            rs2_e_out_reg   <= rs2_e_in;
        end
    end
endmodule

module Mux2to1(input [31:0] a, b, input s, output [31:0] c);
    assign c = s ? b : a;
endmodule

module Mux3to1(input [31:0] a, b, c, input [1:0] s, output [31:0] d);
    assign d = (s == 2'b00) ? a : (s == 2'b01) ? b : c;
endmodule

module ALU (
    input [31:0] A, B,
    input [2:0] ALUControl,
    output reg [31:0] ALUResult,
    output OverFlow, Carry, Zero, Negative
);
    assign OverFlow = 0;
    assign Carry    = 0;
    assign Zero     = (ALUResult == 32'b0);
    assign Negative = ALUResult[31];

    always @(*) begin
        case (ALUControl)
            3'b000: ALUResult = A + B;       // ADD
            3'b001: ALUResult = A - B;       // SUB
            3'b010: ALUResult = A & B;       // AND
            3'b011: ALUResult = A | B;       // OR
            default: ALUResult = 32'b0;
        endcase
    end
endmodule


module PCAdder(input [31:0] a, b, output [31:0] c);
    assign c = a + b;
endmodule

module memory_stage (
    input clk, reset,
    input RegWriteM, MemWriteM,
    input [1:0] ResultSrcM,
    input [4:0] RD_M,
    input [31:0] PCPlus4M, WriteDataM, ALU_ResultM,
    input [31:0] dmem_rdata,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output dmem_we,
    output RegWriteW,
    output [1:0] ResultSrcW,
    output [4:0] RD_W,
    output [31:0] PCPlus4W, ALU_ResultW, ReadDataW
);
    assign dmem_addr = ALU_ResultM;
    assign dmem_wdata = WriteDataM;
    assign dmem_we = MemWriteM;
    assign RegWriteW = RegWriteM;
    assign ResultSrcW = ResultSrcM;
    assign RD_W = RD_M;
    assign PCPlus4W = PCPlus4M;
    assign ALU_ResultW = ALU_ResultM;
    assign ReadDataW = dmem_rdata;
endmodule

module writeback_stage (
    input [1:0] ResultSrcW,
    input [31:0] PCPlus4W, ALU_ResultW, ReadDataW,
    output [31:0] ResultW
);
    assign ResultW = (ResultSrcW == 2'b00) ? ALU_ResultW :
                     (ResultSrcW == 2'b01) ? ReadDataW :
                     PCPlus4W;
endmodule

module hazard_unit (
    input  [4:0] rs1_d, rs2_d,         // rs in  Decode  stage 
    input  [4:0] rs1_e, rs2_e,         // rs in  Execute stage
    input  [4:0] rd_e, rd_m, rd_w,     // rd in  EX, MEM, WB stages
    input        RegWriteM,            // write‑enable in MEM stage
    input        RegWriteW,            // write‑enable in WB  stage
    input  [1:0] ResultSrcE,           // 01 = load 
    input        PCSrcE,               // branch taken
    output       StallF, StallD,
    output       FlushD, FlushE,
    output [1:0] ForwardA_E, ForwardB_E
);

    assign ForwardA_E =
            (RegWriteM && rd_m != 0 && rd_m == rs1_e) ? 2'b10 : // MEM→EX
            (RegWriteW && rd_w != 0 && rd_w == rs1_e) ? 2'b01 : // WB →EX
                                                         2'b00; // use regfile

    assign ForwardB_E =
            (RegWriteM && rd_m != 0 && rd_m == rs2_e) ? 2'b10 :
            (RegWriteW && rd_w != 0 && rd_w == rs2_e) ? 2'b01 :
                                                         2'b00;
    // The tiny test‑programme has no LW‑then‑use in the next slot,
    // so we leave stalls and flushes low.
    assign StallF = 1'b0;
    assign StallD = 1'b0;
    assign FlushD = 1'b0;
    assign FlushE = 1'b0;

endmodule

module data_memory #(parameter MEM_SIZE = 1024)(
    input clk,
    input we,
    input [9:0] addr,
    input [31:0] data_in,
    output [31:0] data_out
);
    reg [31:0] mem [0:MEM_SIZE-1];
    always @(posedge clk) if (we) mem[addr] <= data_in;
    assign data_out = mem[addr];
endmodule
module RISC (
    input  wire        clk,        // System clock
    input  wire        reset       // Active-high reset
);

    // ============================================
    // Memory Interfaces
    // ============================================
    // Instruction memory interface

    wire [31:0] imem_addr;   // Instruction address
    wire [31:0] imem_data;   // Instruction data
    
    // Data memory interface
    wire [31:0] dmem_addr;   // Data address
    wire [31:0] dmem_wdata;  // Data write value
    wire        dmem_we;     // Write enable
    wire [31:0] dmem_rdata;  // Data read value
    
    // ============================================
    // Pipeline Stage Connections
    // ============================================
    
    // Fetch Stage
    wire [31:0] pc_plus4_if;
    
    // IF/ID Pipeline Register
    wire [31:0] pc_id;
    wire [31:0] pc_plus4_id;
    wire [31:0] instr_id;
    
    // ID/EX Pipeline
    wire        RegWrite_id;
    wire        MemWrite_id;
    wire        ALUSrc_id;
    wire [1:0]  ResultSrc_id;
    wire        Branch_id;
    wire        Jump_id;
    wire [2:0]  ALUControl_id;
    wire [31:0] RD1_id;
    wire [31:0] RD2_id;
    wire [31:0] ImmExt_id;
    wire [4:0]  RD_id;
    wire [31:0] pc_plus4_id_out;
    wire [4:0]  rs1_id;
    wire [4:0]  rs2_id;
    
    // EX/MEM Pipeline
    wire        PCSrc_ex;
    wire        RegWrite_ex;
    wire        MemWrite_ex;
    wire [1:0]  ResultSrc_ex;
    wire [4:0]  RD_ex;
    wire [31:0] pc_plus4_ex;
    wire [31:0] WriteData_ex;
    wire [31:0] ALU_Result_ex;
    wire [31:0] PCTarget_ex;
    wire [4:0]  rs1_ex;
    wire [4:0]  rs2_ex;
    
    // MEM/WB Pipeline
    wire        RegWrite_wb;
    wire [1:0]  ResultSrc_wb;
    wire [4:0]  RD_wb;
    wire [31:0] pc_plus4_wb;
    wire [31:0] ALU_Result_wb;
    wire [31:0] ReadData_wb;
    wire [31:0] ResultW;
    
    // ============================================
    // Hazard Detection and Forwarding
    // ============================================
    wire        StallF;
    wire        StallD;
    wire        FlushD;
    wire        FlushE;
    wire [1:0]  ForwardA_ex;
    wire [1:0]  ForwardB_ex;
    
    // ============================================
    // Module Instantiations
    // ============================================
    
    // Instruction Fetch Stage (updated)
    fetch_stage fetch (
        .clk(clk),
        .reset(reset),
        .StallF(StallF),
        .PCSrc(PCSrc_ex),
        .PCTarget(PCTarget_ex),
        .imem_addr(imem_addr),
        .pc_plus4(pc_plus4_if)
    );
    
    // Instruction Memory
    instruction_memory #(
        .MEM_SIZE(1024),
        .INIT_FILE("program.hex")
    ) imem (
        .addr(imem_addr[11:2]),
        .data_out(imem_data)
    );
    
    // IF/ID Pipeline Register
    ifid_reg ifid_inst (
        .clk(clk),
        .reset(reset),
        .FlushD(FlushD),
        .StallD(StallD),
        .pc_in(imem_addr),          // Actual PC from fetch
        .pc_plus4_in(pc_plus4_if),
        .instr_in(imem_data),       // Instruction from memory
        .pc_plus4_out(pc_plus4_id),
        .instr_out(instr_id),
        .pc_out(pc_id)
    );
    
    // Instruction Decode Stage
    decode_stage decode (
        .clk(clk),
        .reset(reset),
        .instr(instr_id),
        .pc(pc_id),
        .RegWrite_wb(RegWrite_wb),
        .RD_wb(RD_wb),
        .ResultW(ResultW),
        .RegWriteE(RegWrite_id),
        .MemWriteE(MemWrite_id),
        .ALUSrcE(ALUSrc_id),
        .ResultSrcE(ResultSrc_id),
        .BranchE(Branch_id),
        .JumpE(Jump_id),
        .ALUControlE(ALUControl_id),
        .RD1E(RD1_id),
        .RD2E(RD2_id),
        .ImmExtE(ImmExt_id),
        .RD_E(RD_id),
        .PCPlus4E(pc_plus4_id_out),
        .rs1(rs1_id),
        .rs2(rs2_id)
    );
    
    // Execute Stage
    execute_cycle execute (
        .clk(clk),
        .rst(reset),
        .RegWriteE(RegWrite_id),
        .ALUSrcE(ALUSrc_id),
        .MemWriteE(MemWrite_id),
        .ResultSrcE(ResultSrc_id),
        .BranchE(Branch_id),
        .JumpE(Jump_id),
        .ALUControlE(ALUControl_id),
        .RD1_E(RD1_id),
        .RD2_E(RD2_id),
        .ImmExtE(ImmExt_id),
        .RD_E(RD_id),
        .PCE(pc_id),
        .PCPlus4E(pc_plus4_id_out),
        .ResultW(ResultW),
        .ForwardA_E(ForwardA_ex),
        .ForwardB_E(ForwardB_ex),
        .rs1_e_in(rs1_id),
        .rs2_e_in(rs2_id),
        .PCSrcE(PCSrc_ex),
        .RegWriteM(RegWrite_ex),
        .MemWriteM(MemWrite_ex),
        .ResultSrcM(ResultSrc_ex),
        .RD_M(RD_ex),
        .PCPlus4M(pc_plus4_ex),
        .WriteDataM(WriteData_ex),
        .ALU_ResultM(ALU_Result_ex),
        .PCTargetE(PCTarget_ex),
        .rs1_e_out(rs1_ex),
        .rs2_e_out(rs2_ex)
    );
    
    // Memory Stage
    memory_stage memory (
        .clk(clk),
        .reset(reset),
        .RegWriteM(RegWrite_ex),
        .MemWriteM(MemWrite_ex),
        .ResultSrcM(ResultSrc_ex),
        .RD_M(RD_ex),
        .PCPlus4M(pc_plus4_ex),
        .WriteDataM(WriteData_ex),
        .ALU_ResultM(ALU_Result_ex),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata),
        .RegWriteW(RegWrite_wb),
        .ResultSrcW(ResultSrc_wb),
        .RD_W(RD_wb),
        .PCPlus4W(pc_plus4_wb),
        .ALU_ResultW(ALU_Result_wb),
        .ReadDataW(ReadData_wb)
    );
    
    // Writeback Stage
    writeback_stage writeback (
        .ResultSrcW(ResultSrc_wb),
        .PCPlus4W(pc_plus4_wb),
        .ALU_ResultW(ALU_Result_wb),
        .ReadDataW(ReadData_wb),
        .ResultW(ResultW)
    );
    
    // Hazard Unit
    hazard_unit hazard (
        .rs1_d(rs1_id),
        .rs2_d(rs2_id),
        .rs1_e(rs1_ex),
        .rs2_e(rs2_ex),
        .rd_e(RD_ex),
        .rd_m(RD_ex),
        .rd_w(RD_wb),
        .RegWriteM(RegWrite_ex),
        .RegWriteW(RegWrite_wb),
        .ResultSrcE(ResultSrc_ex),
        .PCSrcE(PCSrc_ex),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .ForwardA_E(ForwardA_ex),
        .ForwardB_E(ForwardB_ex)
    );
    
    
    // ============================================
    // Memory Instantiations
    // ============================================
    
    // Data Memory
    data_memory #(
        .MEM_SIZE(1024)
    ) dmem (
        .clk(clk),
        .we(dmem_we),
        .addr(dmem_addr[11:2]),
        .data_in(dmem_wdata),
        .data_out(dmem_rdata)
    );
endmodule
