# Computer Architecture Assignment 4

5-stage pipelined MIPS datapath implementation for:

1. Early branch resolution with `beq` and `bne`
2. EX-stage and ID-stage data forwarding
3. Pipeline stall and flush control

## Problems

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
