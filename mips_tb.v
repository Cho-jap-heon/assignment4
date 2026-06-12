`timescale 1ns / 1ps

module mips_tb;
    reg clk;
    reg rst_n;
    wire [31:0] pc_out;
    wire [31:0] alu_result;

    integer i;
    integer failures;
    reg canary_seen;
    reg branch_taken_seen;
    reg mem_forward_seen;
    reg wb_forward_seen;

    mips uut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_out(pc_out),
        .alu_result(alu_result)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task clear_state;
        begin
            rst_n = 0;
            for (i = 0; i < 32; i = i + 1)
                uut.u_datapath.u_reg_file.rf[i] = 32'b0;
            for (i = 0; i < 256; i = i + 1)
                uut.u_datapath.u_imem.ram[i] = 32'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task run_problem1;
        begin
            $display("Problem 1: Early Branch Resolution (BNE)");
            clear_state;
            $readmemh("problem1.dat", uut.u_datapath.u_imem.ram, 0, 3);
            canary_seen = 0;
            branch_taken_seen = 0;
            rst_n = 1;

            repeat (30) begin
                @(negedge clk);
                if (uut.u_datapath.u_reg_file.rf[10] == 32'h00000099)
                    canary_seen = 1;
                if (uut.u_datapath.pc_src_D)
                    branch_taken_seen = 1;
            end

            $display("  $t0 = 0x%08h", uut.u_datapath.u_reg_file.rf[8]);
            $display("  $t1 = 0x%08h", uut.u_datapath.u_reg_file.rf[9]);
            $display("  $t2 = 0x%08h", uut.u_datapath.u_reg_file.rf[10]);
            if (canary_seen || !branch_taken_seen) begin
                if (canary_seen)
                    $display("  FAIL: $t2 reached 0x00000099");
                if (!branch_taken_seen)
                    $display("  FAIL: BNE was never taken");
                failures = failures + 1;
            end else begin
                $display("  PASS: BNE taken and $t2 never reached 0x00000099");
            end
        end
    endtask

    task run_problem2;
        begin
            $display("Problem 2: Data Forwarding");
            clear_state;
            $readmemh("problem2.dat", uut.u_datapath.u_imem.ram, 0, 7);
            mem_forward_seen = 0;
            wb_forward_seen = 0;
            rst_n = 1;

            repeat (15) begin
                @(negedge clk);
                if ((uut.forward_a_E == 2'b10) ||
                    (uut.forward_b_E == 2'b10))
                    mem_forward_seen = 1;
                if ((uut.forward_a_E == 2'b01) ||
                    (uut.forward_b_E == 2'b01))
                    wb_forward_seen = 1;
            end

            $display("  $t0 = 0x%08h", uut.u_datapath.u_reg_file.rf[8]);
            $display("  $t1 = 0x%08h", uut.u_datapath.u_reg_file.rf[9]);
            $display("  $t2 = 0x%08h", uut.u_datapath.u_reg_file.rf[10]);
            $display("  $t3 = 0x%08h", uut.u_datapath.u_reg_file.rf[11]);
            if (!mem_forward_seen || !wb_forward_seen ||
                uut.u_datapath.u_reg_file.rf[10] != 32'h00000003 ||
                uut.u_datapath.u_reg_file.rf[11] != 32'hffffffff) begin
                $display("  FAIL: forwarding result mismatch");
                failures = failures + 1;
            end else begin
                $display("  PASS: MEM/WB forwarding activated and results are correct");
            end
        end
    endtask

    initial begin
        $dumpfile("assignment_04.vcd");
        $dumpvars(0, mips_tb);
        failures = 0;
        rst_n = 0;
        #1;

        run_problem1;
        run_problem2;

        if (failures == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", failures);
        $finish;
    end
endmodule
