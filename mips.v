//==============================================================================
// MIPS 5-Stage Pipelined Processor (Top-Level)
// This module connects the Datapath, Control Unit, and Hazard Unit.
//==============================================================================
`timescale 1ns / 1ps

module mips (
    input  wire        clk,           // System Clock
    input  wire        rst_n,         // Active-Low Reset
    output wire [31:0] pc_out,        // Current Program Counter (for debug)
    output wire [31:0] alu_result     // Final result from WB stage (for debug)
);
    //--------------------------------------------------------------------------
    // 1. Internal Signals (Pipelines and Controls)
    //--------------------------------------------------------------------------
    
    // Control signals from ID stage
    wire [31:0] instr_D;              // Instruction in Decode stage
    wire        reg_write_D, mem_to_reg_D, mem_write_D, branch_D;
    wire        alu_src_D, reg_dst_D;
    wire [2:0]  alu_ctrl_D;
    
    // Hazard & Forwarding management signals
    // rs, rt = source registers; write_reg = destination register
    wire [4:0]  rs_D, rt_D, rs_E, rt_E, write_reg_E, write_reg_M, write_reg_W;
    wire        reg_write_E, reg_write_M, reg_write_W, mem_to_reg_E;
    
    // Forwarding selectors: 00=Reg, 10=MEM result, 01=WB result
    wire [1:0]  forward_a_E, forward_b_E, forward_a_D, forward_b_D;
    
    // Pipeline control: Stall (freeze state) and Flush (clear/bubble)
    wire        stall_F, stall_D, flush_E;

    //--------------------------------------------------------------------------
    // 2. Control Unit (Instruction Decoding)
    //--------------------------------------------------------------------------
    control_unit u_control (
        .opcode(instr_D[31:26]), .funct(instr_D[5:0]),
        .mem_to_reg(mem_to_reg_D), .mem_write(mem_write_D), .branch(branch_D),
        .alu_src(alu_src_D), .reg_dst(reg_dst_D), .reg_write(reg_write_D), .alu_ctrl(alu_ctrl_D)
    );

    //--------------------------------------------------------------------------
    // 3. Hazard Unit (Hardware "Brain")
    // Detects data dependencies and controls stalls/flushes.
    //--------------------------------------------------------------------------
    hazard_unit u_hazard (
        .rs_E(rs_E), .rt_E(rt_E),
        .write_reg_M(write_reg_M), .reg_write_M(reg_write_M),
        .write_reg_W(write_reg_W), .reg_write_W(reg_write_W),
        .rs_D(rs_D), .rt_D(rt_D),
        .branch_D(branch_D),
        .write_reg_E(write_reg_E), .reg_write_E(reg_write_E),
        .rt_E_load(rt_E), .mem_to_reg_E(mem_to_reg_E), 
        .forward_a_E(forward_a_E), .forward_b_E(forward_b_E),
        .forward_a_D(forward_a_D), .forward_b_D(forward_b_D),
        .stall_F(stall_F), .stall_D(stall_D), .flush_E(flush_E)
    );

    //--------------------------------------------------------------------------
    // 4. Datapath (The Physical Pipeline)
    // contains IF, ID, EX, MEM, WB stages and pipeline registers.
    //--------------------------------------------------------------------------
    datapath u_datapath (
        .clk(clk), .rst_n(rst_n),
        // Control Inputs
        .reg_write_D(reg_write_D), .mem_to_reg_D(mem_to_reg_D), .mem_write_D(mem_write_D),
        .alu_ctrl_D(alu_ctrl_D), .alu_src_D(alu_src_D), .reg_dst_D(reg_dst_D), .branch_D(branch_D),
        // Hazard/Forwarding Inputs
        .forward_a_E(forward_a_E), .forward_b_E(forward_b_E),
        .forward_a_D(forward_a_D), .forward_b_D(forward_b_D),
        .stall_F(stall_F), .stall_D(stall_D), .flush_E(flush_E),
        // Feedback Outputs for Hazard/Forwarding
        .rs_D(rs_D), .rt_D(rt_D), .rs_E(rs_E), .rt_E(rt_E), 
        .write_reg_E(write_reg_E), .reg_write_E(reg_write_E), .mem_to_reg_E(mem_to_reg_E),
        .write_reg_M(write_reg_M), .reg_write_M(reg_write_M), 
        .write_reg_W(write_reg_W), .reg_write_W(reg_write_W),
        // Debug/External Outputs
        .instr_out_D(instr_D), .pc_out(pc_out), .alu_result_out(alu_result)
    );
endmodule
