//==============================================================================
// Dual-Read / Single-Write Register File
// Note: This implementation uses a "Timing Trick" for teaching.
// By using ~clk, we ensure that writes happen in the first half of the cycle,
// allowing the new data to be read in the second half of the same cycle.
//==============================================================================
`timescale 1ns / 1ps

module reg_file (
    input  wire        clk,        // Should be connected to ~clk in datapath
    input  wire        we3,        // Write enable
    input  wire [4:0]  wa3,        // Write address (destination)
    input  wire [31:0] wd3,        // Write data
    input  wire [4:0]  ra1,        // Read address 1 (rs)
    input  wire [4:0]  ra2,        // Read address 2 (rt)
    output wire [31:0] rd1,        // Read data 1
    output wire [31:0] rd2         // Read data 2
);
    reg [31:0] rf [31:0];          // 32 registers x 32 bits
    
    // Write logic (Synchronous)
    always @(posedge clk) begin
        if (we3 && (wa3 != 5'd0))  // Register $0 is hardwired to 0
            rf[wa3] <= wd3;
    end
    
    // Read logic (Asynchronous)
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : rf[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : rf[ra2];

endmodule