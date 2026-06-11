//==============================================================================
// Hazard Unit: The Control "Brain" of the Pipelined Processor
// Responsibilities:
// 1. Data Forwarding (to EX and ID stages)
// 2. Load-Use Stall detection
// 3. Control Hazard handling (Branch flushing)
//==============================================================================
`timescale 1ns / 1ps

module hazard_unit (
    // Data Hazard (EX Stage): Current operands in ALU
    input  wire [4:0] rs_E, rt_E,
    // Destination registers and write enables from future stages
    input  wire [4:0] write_reg_M, write_reg_W,
    input  wire       reg_write_M, reg_write_W,
    
    // Data Hazard (ID Stage): For early branch comparison
    input  wire [4:0] rs_D, rt_D,
    input  wire       branch_D,
    input  wire [4:0] write_reg_E,
    input  wire       reg_write_E,
    
    // Control Hazard / Load-Use
    input  wire [4:0] rt_E_load,      // Destination of a current 'lw' in EX
    input  wire       mem_to_reg_E,   // Is the EX instruction a 'lw'?
    
    // OUTPUTS: Control selectors for Datapath Muxes
    output reg  [1:0] forward_a_E, forward_b_E, // ALU operands
    output reg  [1:0] forward_a_D, forward_b_D, // Branch operands
    output wire       stall_F, stall_D, flush_E // Pipeline control
);
    //--------------------------------------------------------------------------
    // 1. Forwarding to EX Stage (ALU Inputs)
    // Priority: MEM stage result is newer than WB stage result.
    //--------------------------------------------------------------------------
    always @(*) begin
        // Source A (rs_E) Forwarding
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rs_E))
            forward_a_E = 2'b10; // Forward from MEM stage
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rs_E))
            forward_a_E = 2'b01; // Forward from WB stage
        else
            forward_a_E = 2'b00; // Use register data (no forwarding)

        // Source B (rt_E) Forwarding
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rt_E))
            forward_b_E = 2'b10;
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rt_E))
            forward_b_E = 2'b01;
        else
            forward_b_E = 2'b00;
    end

    //--------------------------------------------------------------------------
    // 2. Forwarding to ID Stage (Early Branch Comparison)
    // Ensures 'beq' uses the most up-to-date data without stalling if possible.
    //--------------------------------------------------------------------------
    always @(*) begin
        // Rs in Decode stage
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rs_D))
            forward_a_D = 2'b10; // Result available from MEM stage
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rs_D))
            forward_a_D = 2'b01; // Result available in WB stage
        else
            forward_a_D = 2'b00;
        
        // Rt in Decode stage
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rt_D))
            forward_b_D = 2'b10;
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rt_D))
            forward_b_D = 2'b01;
        else
            forward_b_D = 2'b00;
    end

    //--------------------------------------------------------------------------
    // 3. Stalls and Flushes (Load-Use Hazard)
    // If 'lw' is in EX and the next instruction needs that data, we MUST stall.
    //--------------------------------------------------------------------------
    wire lwstall;
    wire branchstall;
    // Condition: lw is in EX AND its destination (rt_E_load) matches rs_D or rt_D.
    assign lwstall = mem_to_reg_E && (rt_E_load != 0) &&
                     ((rt_E_load == rs_D) || (rt_E_load == rt_D));

    // The ID-stage comparator cannot consume an ALU result still in EX.
    assign branchstall = branch_D && reg_write_E && (write_reg_E != 0) &&
                         ((write_reg_E == rs_D) || (write_reg_E == rt_D));
    
    // If lwstall is high:
    assign stall_F = lwstall || branchstall;
    assign stall_D = lwstall || branchstall;
    assign flush_E = lwstall || branchstall;

endmodule
