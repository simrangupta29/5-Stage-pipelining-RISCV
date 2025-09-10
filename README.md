RISC-V Pipeline Core <br>

📌 Overview
This project implements a pipelined RISC-V processor architecture, breaking down the single-cycle processor into five pipeline stages. The design allows multiple instructions to execute simultaneously—one per stage—improving performance and achieving higher clock frequency.

<img width="1890" height="846" alt="schematic_riscv_processor" src="https://github.com/user-attachments/assets/8a634b38-0e67-44bc-9cd5-a78519755cf6" />


Schematic view of RISC-V processor.

The pipeline consists of the following stages:
<img width="952" height="618" alt="image" src="https://github.com/user-attachments/assets/59815e0e-1a08-4c1e-9cda-717fb0e5d2e9" />

Fetch

Decode

Execute

Memory

Write Back

Additionally, the project explores pipeline hazards and their solutions using techniques like forwarding and bypassing.

🏗️ Pipeline Implementation
1. Fetch Cycle

Modules:

PC Mux

Program Counter

Adder

Instruction Memory

Fetch Stage Registers

2. Decode Cycle

Modules:

Control Unit

Register File

Extender

Decode Stage Registers

3. Execute Cycle

Modules:

AND Gate

Mux

Adder

ALU

Execute Stage Registers

4. Memory Cycle

Modules:

Data Memory

Memory Stage Registers

5. Write Back Cycle

Modules:

Multiplexer

⚡ Pipeline Hazards
Structural Hazards

Occur when hardware does not support execution of multiple instructions in the same clock cycle.

Example: Without dual memories, RISC-V pipelining faces structural hazards.

Data Hazards

Arise when required data is not available in time.

Solutions:

Inserting NOPs

Forwarding / Bypassing techniques

🔧 Hazard Unit Implementation

The hazard unit resolves data hazards by controlling forwarding signals based on conditions:

Memory Stage Forwarding

if (RegWriteM and (RdM != 0) and (RdM == Rs1E)) ForwardAE = 10  
if (RegWriteM and (RdM != 0) and (RdM == Rs2E)) ForwardBE = 10  


Write Back Stage Forwarding

if (RegWriteW and (RdW != 0) and (RdW == Rs1E)) ForwardAE = 01  
if (RegWriteW and (RdW != 0) and (RdW == Rs2E)) ForwardBE = 01  

📂 Project Structure
├── FetchCycle/  
├── DecodeCycle/  
├── ExecuteCycle/  
├── MemoryCycle/  
├── WriteBackCycle/  
├── HazardUnit/  
└── PipelineTop/  

📖 Learnings

Designing a RISC-V pipelined architecture

Handling structural and data hazards

Implementing a hazard unit with forwarding/bypassing

Improving performance through pipelining

🛠️ Tools & Technologies

RISC-V ISA

Verilog / VHDL (for implementation)
Simulation tools (ModelSim / Vivado / etc.)

🙌 Acknowledgments

This project is inspired by the principles of computer architecture and pipeline design, focusing on practical implementation of the RISC-V ISA.
