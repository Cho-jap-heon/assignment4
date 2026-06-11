//==============================================================================
// Data Memory (DM)
// Features: Word-aligned addressing and Synchronous write.
//==============================================================================
`timescale 1ns / 1ps

module data_memory #(
    parameter WIDTH = 32,
    parameter DEPTH = 256
)(
    input  wire        clk,
    input  wire        mem_write_en,   // Write enable
    input  wire [31:0] addr,           // Byte address
    input  wire [31:0] write_data,     // Data to store
    output wire [31:0] read_data       // Data to load
);
    reg [WIDTH-1:0] ram [0:DEPTH-1];
    
    // Address is divided by 4 for word-alignment (e.g., 0x4 -> index 1)
    assign read_data = ram[addr[31:2]];

    always @(posedge clk) begin
        if (mem_write_en) begin
            ram[addr[31:2]] <= write_data;
        end
    end
endmodule