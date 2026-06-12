Problem 1 · Early Branch Resolution 
wire bne_D = (instr_D[31:26] == 6'b000101);
assign pc_src_D = branch_D &
(bne_D ? ~(rd1_D == rd2_D)
: (rd1_D == rd2_D));
Convert the following instructions to hex machine code, and simulate using your pipelined MIPS datapath.

To verify, the register addresses are: $t0 = 8, $t1 = 9, $t2 = 10

Verify that $t2 never reaches 0x99.

Problem 2 · Data Forwarding 
2008000A // addi $t0, $0, 10
20090005 // addi $t1, $0, 5
1509FFFD // bne $t0, $t1, -3 (10 ≠ 5, taken — jump back to 0x0)
200A0099 // addi $t2, $0, 0x99 (CANARY — must never execute)
Convert the following instructions to hex machine code, and simulate using your pipelined MIPS datapath.

To verify, the register addresses are: $t0 = 8, $t1 = 9, $t2 = 10, $t3 = 11

RegWrite = 쓸 거야?
WriteReg = 어디에 쓸 거야?
add $s0, $s1, $s2   // RegWrite = 1
lw  $s0, 0($s1)     // RegWrite = 1
sw  $s0, 0($s1)     // RegWrite = 0
beq $s0, $s1, L     // RegWrite = 0
레지스터에 안 쓰는 명령어는 forwarding할 필요가 없음
write_reg_M != 5'd0 
### Problem 1: Early Branch Resolution

```text
2008000A  # addi $t0, $zero, 10
20090005  # addi $t1, $zero, 5
1509FFFD  # bne  $t0, $t1, -3
200A0099  # addi $t2, $zero, 0x99 (canary)
```

Because `10 != 5`, the branch returns to address `0x00`. The instruction at
`0x0C` is flushed, so `$t2` must never become `0x00000099`.

### Problem 2: Data Forwarding

```text
20080001  # addi $t0, $zero, 1
20090002  # addi $t1, $zero, 2
01095020  # add  $t2, $t0, $t1
012A5822  # sub  $t3, $t1, $t2
```

The dependent `add` and `sub` instructions receive recent results through the
MEM/WB forwarding paths. Expected register values are:

| Register | Address | Expected value |
|---|---:|---:|
| `$t0` | 8 | `0x00000001` |
| `$t1` | 9 | `0x00000002` |
| `$t2` | 10 | `0x00000003` |
| `$t3` | 11 | `0xFFFFFFFF` |

## Run

Requirements: Icarus Verilog and GNU Make.

```sh
make
```

The self-checking testbench prints `ALL TESTS PASSED` when both problems pass.
It also creates `assignment_04.vcd` for waveform inspection.

```sh
make wave
```

See [ASSIGNMENT.md](ASSIGNMENT.md) for the instruction encoding and a Korean
explanation of the pipeline behavior.
