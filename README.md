# Class 09: Hazard Unit - Stall & Flush

> **Week 09 | Hanyang University ERICA Campus | Department of Robotics**  
> **Computer Architecture Course**

---

## 📚 Learning Objectives

After completing this class, you will be able to:

1. **Understand Load-Use hazards**: Why forwarding cannot solve all data hazards
2. **Implement pipeline stall**: Make the pipeline "wait"
3. **Implement pipeline flush**: Clear incorrectly executed instructions
4. **Design a unified hazard unit**: Integrate forwarding, stalling, and flushing logic

---

## 🧠 Key Concepts

### Load-Use Hazard: What Forwarding Can't Solve

```assembly
lw  $t0, 0($t1)   # Load from memory (data available at end of MEM stage)
add $t2, $t0, $t3 # Immediately use $t0 (needs data in EX stage)
```

**Timing Analysis**:

```
Cycle |   IF   |   ID   |   EX   |   MEM  |   WB
------|--------|--------|--------|--------|--------
  1   | lw     |        |        |        |
  2   | add    | lw     |        |        |
  3   |        | add    | lw     |        |    ← add needs $t0
  4   |        |        | add    |lw→data |    ← data available here
```

**Problem**: `add` needs `$t0` in cycle 3 EX stage, but `lw` data isn't available until end of cycle 4 MEM stage.

**Only solution**: Make `add` wait one cycle (stall)!

### Stall Mechanism Implementation

```
Cycle |   IF   |   ID   |   EX   |   MEM  |   WB
------|--------|--------|--------|--------|--------
  1   | lw     |        |        |        |
  2   | add    | lw     |        |        |
  3   | add    | add    | lw     |        |    ← stall: IF, ID freeze
  4   | ...    | add    | NOP    | lw     |    ← insert bubble
  5   |        | ...    | add ✓  | NOP    | lw ← now can forward
```

**Three control signals**:
- `stall_F`: Freeze PC, don't fetch new instruction
- `stall_D`: Freeze IF/ID register, keep current instruction
- `flush_E`: Clear ID/EX control signals to zero, insert "bubble"

---

## 📊 Hazard Unit Overview

```
                ┌──────────────────────────────────────────────┐
                │              Hazard Unit                     │
                │                                              │
  rs_D, rt_D ───┼───→┌─────────────────┐                       │
                │    │  Load-Use       │───→ stall_F           │
  rs_E, rt_E ───┼───→│  Detection      │───→ stall_D           │
                │    │                 │───→ flush_E           │
  write_reg_E ──┼───→└─────────────────┘                       │
  mem_to_reg_E ─┼───→                                          │
                │    ┌─────────────────┐                       │
  write_reg_M ──┼───→│  EX Forwarding  │───→ forward_a_E       │
  reg_write_M ──┼───→│  Logic          │───→ forward_b_E       │
  write_reg_W ──┼───→│                 │                       │
  reg_write_W ──┼───→└─────────────────┘                       │
                │    ┌─────────────────┐                       │
  branch_D ─────┼───→│  ID Forwarding  │───→ forward_a_D       │
                │    │  (for branch)   │───→ forward_b_D       │
                │    └─────────────────┘                       │
                └──────────────────────────────────────────────┘
```

---

## 💻 Code Walkthrough

### Unified Hazard Unit

```verilog
module hazard_unit (
    // EX stage signals
    input  wire [4:0] rs_E, rt_E,
    input  wire [4:0] write_reg_E,
    input  wire       reg_write_E,
    input  wire       mem_to_reg_E,  // Is it a lw instruction
    
    // MEM stage signals
    input  wire [4:0] write_reg_M,
    input  wire       reg_write_M,
    input  wire       mem_to_reg_M,
    
    // WB stage signals
    input  wire [4:0] write_reg_W,
    input  wire       reg_write_W,
    
    // ID stage signals (for branch)
    input  wire [4:0] rs_D, rt_D,
    input  wire       branch_D,
    
    // Output: forwarding signals
    output reg  [1:0] forward_a_E, forward_b_E,
    output reg  [1:0] forward_a_D, forward_b_D,
    
    // Output: stall/flush signals
    output wire       stall_F, stall_D, flush_E
);
```

### Load-Use Hazard Detection

```verilog
    // Load-Use detection: EX stage is lw, and ID stage needs its result
    wire lw_stall;
    assign lw_stall = mem_to_reg_E &&
                      ((rs_D == write_reg_E) || (rt_D == write_reg_E));
```

### Branch Stall Detection

```verilog
    // Branch stall: branch instruction needs data still in EX or MEM stage lw
    wire branch_stall;
    assign branch_stall = branch_D && (
        // Previous instruction is ALU, result still in EX
        (reg_write_E && ((rs_D == write_reg_E) || (rt_D == write_reg_E))) ||
        // Two instructions back is lw, result still in MEM
        (mem_to_reg_M && ((rs_D == write_reg_M) || (rt_D == write_reg_M)))
    );
```

### Control Signal Output

```verilog
    // Final control signals
    assign stall_F = lw_stall || branch_stall;
    assign stall_D = lw_stall || branch_stall;
    assign flush_E = lw_stall || branch_stall;
```

### EX Stage Forwarding Logic

```verilog
    // EX stage forwarding
    always @(*) begin
        // Forward A
        if (reg_write_M && write_reg_M != 0 && write_reg_M == rs_E)
            forward_a_E = 2'b10;  // MEM forwarding
        else if (reg_write_W && write_reg_W != 0 && write_reg_W == rs_E)
            forward_a_E = 2'b01;  // WB forwarding
        else
            forward_a_E = 2'b00;  // No forwarding
            
        // Forward B (same logic)
        // ...
    end
```

---

## 🎯 Stall Signal Effects

| Signal | Target | Effect |
|--------|--------|--------|
| `stall_F` | PC register | Prevent PC update, freeze fetch |
| `stall_D` | IF/ID register | Keep current instruction unchanged |
| `flush_E` | ID/EX register | Clear all control signals to zero (insert NOP) |

### Connection in Datapath

```verilog
// PC register
pc u_pc (
    .clk(clk), .rst_n(rst_n),
    .en(~stall_F),        // Disable update when stalled
    .pc_next(pc_next_F), .pc(pc_F)
);

// IF/ID register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset
    end else if (!stall_D) begin  // Keep when stalled
        instr_D_reg <= instr_F;
        pc_plus4_D  <= pc_plus4_F;
    end
end

// ID/EX register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_E) begin  // Clear when flushed
        reg_write_E <= 0;
        mem_write_E <= 0;
        // ... all control signals cleared
    end else begin
        // Normal propagation
    end
end
```

---

## 📁 File Structure

```
class_09/
├── hazard_unit.v           # Unified hazard unit ⭐
├── datapath.v              # Complete pipelined datapath
├── mips.v                  # CPU top level
└── ...
```

> ⚠️ **Important**: Starting from this class, `forwarding_unit.v` logic has been merged into `hazard_unit.v`.

---

## 🧪 Lab Exercise

### Step 1: Test Load-Use Hazard (`memfile.dat`)
```
8C080000   // lw   $t0, 0($zero)  → Load from Mem[0]
01085020   // add  $t2, $t0, $t0  → Load-Use hazard!
200B0005   // addi $t3, $zero, 5  → Verify pipeline recovery
```

### Step 2: Run simulation
```bash
cd class_09
make
```

### Step 3: Observe waveform
- Verify `stall_F/D` and `flush_E` activate during Load-Use hazard
- Verify PC stays unchanged during stall cycle
- Verify ID/EX stage shows "bubble" (all control signals zero)

---

## 🔍 Think Deeper

### Question 1: Stall vs Compiler Optimization

Compilers can avoid Load-Use hazards through **instruction reordering**:
```assembly
lw   $t0, 0($t1)
# Compiler inserts an instruction here that doesn't depend on $t0
add  $t2, $t0, $t3
```
What are the pros and cons compared to hardware stalling?

### Question 2: Multi-cycle Stall

What happens if two consecutive `lw` instructions are followed by an instruction that depends on them?

### Question 3: Performance Impact of Stalling

If 20% of instructions are `lw`, and 50% of `lw` are followed by Load-Use hazards, what is the average CPI of the pipeline?

---

## 🏆 Milestone

> **Congratulations!** After completing this class, your MIPS CPU has complete hazard handling capability:
> 
> - ✅ **Data Forwarding**: Avoids most data hazards
> - ✅ **Pipeline Stall**: Handles Load-Use hazards
> - ✅ **Branch Flush**: Handles control hazards
> 
> This is now a **fully functional 5-stage pipelined MIPS CPU**!

---

## ✅ Checkpoint

Before moving to the next class, make sure you can answer:

- [ ] Why can't Load-Use hazards be solved by forwarding?
- [ ] What is the purpose of the `flush_E` signal?
- [ ] After stalling for one cycle, which pipeline register values change?

---

**Previous**: [Class 08 - Data Forwarding](../class_08/README.md)  
**Next**: [Class 10 - Jump Instructions](../class_10/README.md)
