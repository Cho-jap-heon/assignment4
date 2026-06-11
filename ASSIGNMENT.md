# Computer Architecture Assignment 4

## Problem 1: Early Branch Resolution

| Address | Assembly | Hex |
|---:|---|---:|
| `0x00` | `addi $t0, $zero, 10` | `2008000A` |
| `0x04` | `addi $t1, $zero, 5` | `20090005` |
| `0x08` | `bne $t0, $t1, -3` | `1509FFFD` |
| `0x0C` | `addi $t2, $zero, 0x99` | `200A0099` |

The branch target is:

`0x0C + (sign_extend(0xFFFD) << 2) = 0x0C - 12 = 0x00`

`bne` has opcode `000101`, so the ID-stage decision is:

```verilog
wire bne_D = (instr_D[31:26] == 6'b000101);
assign pc_src_D = branch_D &
                  (bne_D ? (src_a_D != src_b_D)
                         : (src_a_D == src_b_D));
```

The branch waits one cycle when a required result is still in EX, then uses
ID-stage forwarding from MEM/WB. A taken branch flushes the IF/ID register, so
the canary instruction never reaches WB and `$t2` never becomes `0x99`.

## Problem 2: Data Forwarding

The prompt did not include a second assembly listing. The supplied test uses
the standard dependent sequence:

| Address | Assembly | Hex |
|---:|---|---:|
| `0x00` | `addi $t0, $zero, 1` | `20080001` |
| `0x04` | `addi $t1, $zero, 2` | `20090002` |
| `0x08` | `add $t2, $t0, $t1` | `01095020` |
| `0x0C` | `sub $t3, $t1, $t2` | `012A5822` |

Expected final values:

- `$t0 = 0x00000001`
- `$t1 = 0x00000002`
- `$t2 = 0x00000003`
- `$t3 = 0xFFFFFFFF`

Run with:

```text
make
```
