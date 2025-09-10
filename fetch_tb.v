module tb();

    reg clk=0, rst,PCSrcE;
    reg[31:0] PCTargetE;
    wire[31:0] InstrD, PCD, PCPlus4D;
 fetch_cycle dut (.clk(clk),
                  .rst(rst), 
                  .PCSrcE(PCSrcE),
                  .PCTargetE(PCTargetE), 
                  .InstrD(InstrD), 
                   .PCD(PCD),
                   .PCPlus4D(PCPlus4D));
    always begin
        clk = ~clk;
        #50;
    end

    initial begin
        rst <= 1'b0;
        #200;
        rst <= 1'b1;
        PCSrcE<=1'b0;
        PCTargetE<=32'h00000000;
        #500;
        $finish;    
    end
// geberation of vcd file
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    always @(posedge clk) begin
    $display("%0t clk=%b rst=%b PCD=%h PCPlus4D=%h InstrD=%h PCsrc=%b PCT=%h",
             $time, clk, rst, PCD, PCPlus4D, InstrD, PCSrcE, PCTargetE);
  end
endmodule