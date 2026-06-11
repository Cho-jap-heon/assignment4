//==============================================================================
// Program Counter (PC) Register
// Features: Stalling support (via 'en' signal) and Asynchronous Reset.
//==============================================================================
`timescale 1ns / 1ps

module pc (
    input  wire        clk,        // Clock
    input  wire        rst_n,      // Active-Low Reset
    input  wire        en,         // Enable: 1 = update PC, 0 = freeze PC (Stall)
    input  wire [31:0] pc_next,    // Next address from branch mux
    output reg  [31:0] pc          // Current fetch address
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // PC starts at 0x00000000 after reset
            pc <= 32'd0; 
        end else if (en) begin
            // Only update PC if NOT stalled by Hazard Unit
            pc <= pc_next; 
        end
    end
endmodule