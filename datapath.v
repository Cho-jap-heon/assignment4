//==============================================================================
// 5-Stage MIPS Pipelined Datapath
// Stages: IF (Fetch), ID (Decode), EX (Execute), MEM (Memory), WB (Writeback)
// Includes Pipeline Registers and Hazard/Forwarding support.
//==============================================================================
`timescale 1ns / 1ps

module datapath (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control bus from ID stage (Main & ALU Decoder)
    input  wire        reg_write_D,
    input  wire        mem_to_reg_D,
    input  wire        mem_write_D,
    input  wire [2:0]  alu_ctrl_D,
    input  wire        alu_src_D,
    input  wire        reg_dst_D,
    input  wire        branch_D,
    
    // Hazard/Forwarding control signals from Hazard Unit
    input  wire [1:0]  forward_a_E,   // Forward logic for ALU src A
    input  wire [1:0]  forward_b_E,   // Forward logic for ALU src B
    input  wire [1:0]  forward_a_D,   // Forward logic for Branch src A
    input  wire [1:0]  forward_b_D,   // Forward logic for Branch src B
    input  wire        stall_F,       // Freeze PC
    input  wire        stall_D,       // Freeze IF/ID register
    input  wire        flush_E,       // Clear ID/EX register (insert bubble)
    
    // Feedback to Hazard Unit
    output wire [4:0]  rs_D, rt_D,    // Reg addresses in Decode
    output wire [4:0]  rs_E, rt_E,    // Reg addresses in Execute
    output wire [4:0]  write_reg_E,   // Dest reg in Execute
    output wire        reg_write_E,   // Write enable in Execute
    output wire        mem_to_reg_E,  // Signal to detect Load-Use hazard
    output wire [4:0]  write_reg_M,   // Dest reg in Memory
    output wire        reg_write_M,   // Write enable in Memory
    output wire [4:0]  write_reg_W,   // Dest reg in Writeback
    output wire        reg_write_W,   // Write enable in Writeback
    
    // Observability / Inter-module signals
    output wire [31:0] instr_out_D,   // Instruction to Control Unit
    output wire [31:0] pc_out,        // PC for simulation/debug
    output wire [31:0] alu_result_out // Result for simulation/debug
);

    //--------------------------------------------------------------------------
    // --- STAGE 1: FETCH (F) ---
    //--------------------------------------------------------------------------
    wire [31:0] pc_F, pc_next_F, pc_plus4_F, instr_F;
    wire        pc_src_D;           // Decision from Early Branch logic
    wire [31:0] pc_branch_D;        // Target from Early Branch logic
    
    // Program Counter Logic
    pc u_pc (.clk(clk), .rst_n(rst_n), .en(!stall_F), .pc_next(pc_next_F), .pc(pc_F));
    
    // Instruction Memory (Async read)
    instruction_memory u_imem (.addr(pc_F), .rd(instr_F));
    
    assign pc_plus4_F = pc_F + 32'd4;
    assign pc_next_F  = (pc_src_D) ? pc_branch_D : pc_plus4_F;
    assign pc_out     = pc_F;

    // --- IF/ID Pipeline Register ---
    reg [31:0] instr_D_reg, pc_plus4_D;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            instr_D_reg <= 0; pc_plus4_D <= 0; 
        end else if (!stall_D) begin
            if (pc_src_D) begin 
                // Branch Taken: Flush the fetching instruction (Control Hazard)
                instr_D_reg <= 0; pc_plus4_D <= 0;
            end else begin
                // Normal Update
                instr_D_reg <= instr_F; pc_plus4_D <= pc_plus4_F;
            end
        end
    end
    assign instr_out_D = instr_D_reg;
    assign rs_D = instr_D_reg[25:21];
    assign rt_D = instr_D_reg[20:16];

    //--------------------------------------------------------------------------
    // --- STAGE 2: DECODE (D) ---
    //--------------------------------------------------------------------------
    wire [31:0] rd1_D, rd2_D, sign_imm_D, result_W;
    
    // Register File: Dual Read / Single Write (at WB stage)
    // Note: Uses ~clk to allow WB to write in 1st half of cycle and ID to read in 2nd half.
    reg_file u_reg_file (
        .clk(~clk), .we3(reg_write_W), 
        .ra1(rs_D), .ra2(rt_D), 
        .wa3(write_reg_W), .wd3(result_W), 
        .rd1(rd1_D), .rd2(rd2_D)
    );
    
    // Sign Extension: Converts 16-bit immediate to 32-bit
    assign sign_imm_D = {{16{instr_D_reg[15]}}, instr_D_reg[15:0]};
    
    // --- Early Branch Resolution ---
    // Logic moved to ID to reduce branch penalty to 1 cycle.
    // Needs Forwarding because operands might still be in EX or MEM stages.
    wire [31:0] src_a_D, src_b_D;
    wire [31:0] alu_result_M_wire;
    assign src_a_D = (forward_a_D == 2'b10) ? alu_result_M_wire :
                     (forward_a_D == 2'b01) ? result_W : rd1_D;
    assign src_b_D = (forward_b_D == 2'b10) ? alu_result_M_wire :
                     (forward_b_D == 2'b01) ? result_W : rd2_D;
    
    wire bne_D;
    assign bne_D       = (instr_D_reg[31:26] == 6'b000101);
    assign pc_branch_D = pc_plus4_D + (sign_imm_D << 2);
    assign pc_src_D    = branch_D &
                         (bne_D ? (src_a_D != src_b_D)
                                : (src_a_D == src_b_D));

    // --- ID/EX Pipeline Register ---
    reg        reg_write_E_reg, mem_to_reg_E_reg, mem_write_E, alu_src_E, reg_dst_E;
    reg [2:0]  alu_ctrl_E;
    reg [31:0] rd1_E, rd2_E, sign_imm_E;
    reg [4:0]  rs_E_reg, rt_E_reg, rd_E;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_E) begin
            // flush_E inserts a bubble (nop) when a Load-Use hazard is detected
            {reg_write_E_reg, mem_to_reg_E_reg, mem_write_E, alu_src_E, reg_dst_E} <= 0;
            alu_ctrl_E <= 0; {rd1_E, rd2_E, sign_imm_E} <= 0; {rs_E_reg, rt_E_reg, rd_E} <= 0;
        end else begin
            reg_write_E_reg <= reg_write_D; mem_to_reg_E_reg <= mem_to_reg_D; mem_write_E <= mem_write_D;
            alu_ctrl_E <= alu_ctrl_D; alu_src_E <= alu_src_D; reg_dst_E <= reg_dst_D;
            rd1_E <= rd1_D; rd2_E <= rd2_D; sign_imm_E <= sign_imm_D;
            rs_E_reg <= rs_D; rt_E_reg <= rt_D; rd_E <= instr_D_reg[15:11];
        end
    end
    assign rs_E = rs_E_reg;
    assign rt_E = rt_E_reg;
    assign reg_write_E = reg_write_E_reg;
    assign mem_to_reg_E = mem_to_reg_E_reg;

    //--------------------------------------------------------------------------
    // --- STAGE 3: EXECUTE (E) ---
    //--------------------------------------------------------------------------
    wire [31:0] src_a_E_final, src_b_E_temp, src_b_E_final;
    wire [31:0] alu_result_E;
    wire        zero_E;
    
    // ALU Source A Mux (with Forwarding from MEM or WB stage)
    assign src_a_E_final = (forward_a_E == 2'b10) ? alu_result_M_wire :
                           (forward_a_E == 2'b01) ? result_W : rd1_E;
                           
    // ALU Source B Mux (Part 1: Forwarding)
    assign src_b_E_temp  = (forward_b_E == 2'b10) ? alu_result_M_wire :
                           (forward_b_E == 2'b01) ? result_W : rd2_E;
                           
    // ALU Source B Mux (Part 2: Select between register data or immediate)
    assign src_b_E_final = (alu_src_E) ? sign_imm_E : src_b_E_temp;
    
    // Destination Register Selection (rt for I-type, rd for R-type)
    assign write_reg_E   = (reg_dst_E) ? rd_E : rt_E_reg;
    
    alu u_alu (
        .src_a(src_a_E_final), .src_b(src_b_E_final), 
        .alu_ctrl(alu_ctrl_E), .result(alu_result_E), .zero(zero_E)
    );

    // --- EX/MEM Pipeline Register ---
    reg        reg_write_M_reg, mem_to_reg_M, mem_write_M;
    reg [31:0] alu_result_M_reg, write_data_M;
    reg [4:0]  write_reg_M_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_M_reg, mem_to_reg_M, mem_write_M} <= 0;
            {alu_result_M_reg, write_data_M} <= 0; write_reg_M_reg <= 0;
        end else begin
            reg_write_M_reg <= reg_write_E_reg; mem_to_reg_M <= mem_to_reg_E_reg; mem_write_M <= mem_write_E;
            alu_result_M_reg <= alu_result_E; write_data_M <= src_b_E_temp; write_reg_M_reg <= write_reg_E;
        end
    end
    assign alu_result_M_wire = alu_result_M_reg;
    assign write_reg_M = write_reg_M_reg;
    assign reg_write_M = reg_write_M_reg;

    //--------------------------------------------------------------------------
    // --- STAGE 4: MEMORY (M) ---
    //--------------------------------------------------------------------------
    wire [31:0] read_data_M;
    
    data_memory u_data_mem (
        .clk(clk), .mem_write_en(mem_write_M), 
        .addr(alu_result_M_reg), .write_data(write_data_M), .read_data(read_data_M)
    );

    // --- MEM/WB Pipeline Register ---
    reg        reg_write_W_reg, mem_to_reg_W;
    reg [31:0] read_data_W, alu_result_W;
    reg [4:0]  write_reg_W_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_W_reg, mem_to_reg_W} <= 0; {read_data_W, alu_result_W} <= 0; write_reg_W_reg <= 0;
        end else begin
            reg_write_W_reg <= reg_write_M_reg; mem_to_reg_W <= mem_to_reg_M;
            read_data_W <= read_data_M; alu_result_W <= alu_result_M_reg; write_reg_W_reg <= write_reg_M_reg;
        end
    end
    assign write_reg_W = write_reg_W_reg;
    assign reg_write_W = reg_write_W_reg;

    //--------------------------------------------------------------------------
    // --- STAGE 5: WRITEBACK (W) ---
    //--------------------------------------------------------------------------
    // Select between ALU result and data from Memory to write back to RegFile
    assign result_W = (mem_to_reg_W) ? read_data_W : alu_result_W;
    
    assign alu_result_out = result_W;
endmodule
