# 8-Bit Custom CPU Architecture with Cache Hierarchy

A custom-designed 8-bit CPU core implemented in Verilog HDL featuring a 32-bit fixed-length Instruction Set Architecture (ISA) inspired by the MIPS architecture, a modular Arithmetic Logic Unit (ALU), a multi-level Memory & Cache Hierarchy (Instruction Cache & Write-Back Data Cache), stall-based pipeline flow control, and a dedicated C-based assembler toolchain.

---

## Architectural Overview

This processor design was developed by F.R. Sujeevan during his second year of computer engineering studies to demonstrate fundamental computer organization principles, ranging from gate-level timing modeling up to high-level memory hierarchy management.

The core architecture design and ISA are inspired by the MIPS RISC architecture as presented in the textbook:
* *Computer Organization and Design: The Hardware/Software Interface, Sixth Edition*, by David A. Patterson and John L. Hennessy.

While foundational memory primitive modules and utility scripts were provided as course resources, all processor architecture logic, instruction decoding, register file operations, ALU functions, 2's complement logic, and cache hierarchy subsystems were designed and implemented independently by F.R. Sujeevan.

### Specifications
* Data Width: 8-bit data paths and registers.
* Instruction Width: 32-bit fixed-length instruction encoding (MIPS-style fixed format).
* Register File: 8 general-purpose 8-bit registers (r0 through r7).
* Addressing: 32-bit Program Counter (PC), byte-addressable instruction and data spaces.
* Instruction Cache: 128 Bytes, Direct-Mapped, 16-Byte block size, read-only.
* Instruction Memory: 1024 Bytes (256 blocks of 16 Bytes), 40ns block read delay.
* Data Cache: 32 Bytes, Direct-Mapped, 4-Byte block size, Write-Back with Dirty bit, Write-Allocate.
* Data Memory: 256 Bytes (64 blocks of 4 Bytes), 40ns block access delay.
* Flow Control: Support for conditional branching (beq), sign-extended target offsets, unconditional jumping (j), and unified cache stall logic (BUSYWAIT).

---

## Instruction Set Architecture (ISA)

The CPU utilizes a 32-bit fixed-format instruction word partitioned into four 8-bit fields:

Opcode (bits 31 to 24), Destination or Immediate (bits 23 to 16), Source Register 1 or RT (bits 15 to 8), and Source Register 2 or Immediate (bits 7 to 0).

### Instruction Reference

| Instruction | Opcode (Hex) | Operands | Operation | Description |
| :--- | :---: | :--- | :--- | :--- |
| loadi | 0x00 | RD, IMM | Reg[RD] = IMM | Load 8-bit immediate value into RD |
| mov | 0x01 | RD, RT | Reg[RD] = Reg[RT] | Move register contents from RT to RD |
| add | 0x02 | RD, RT, RS | Reg[RD] = Reg[RT] + Reg[RS] | Unsigned addition |
| sub | 0x03 | RD, RT, RS | Reg[RD] = Reg[RT] - Reg[RS] | Subtraction via 2's complement |
| and | 0x04 | RD, RT, RS | Reg[RD] = Reg[RT] & Reg[RS] | Bitwise AND operation |
| or | 0x05 | RD, RT, RS | Reg[RD] = Reg[RT] \| Reg[RS] | Bitwise OR operation |
| j | 0x06 | TARGET | PC = PC + 4 + (SignExt(OFFSET) << 2) | Unconditional jump |
| beq | 0x07 | OFFSET, RT, RS | if (Reg[RT] == Reg[RS]) PC = PC + 4 + (SignExt(OFFSET) << 2) | Branch if equal |
| lwd | 0x08 | RD, RT | Reg[RD] = Mem[Reg[RT]] | Load byte from memory address in RT |
| lwi | 0x09 | RD, IMM | Reg[RD] = Mem[IMM] | Load byte from memory address IMM |
| swd | 0x0A | RT, RS | Mem[Reg[RS]] = Reg[RT] | Store byte in RT to memory address in RS |
| swi | 0x0B | RT, IMM | Mem[IMM] = Reg[RT] | Store byte in RT to memory address IMM |

---

## Datapath and Sub-Modules

### 1. Arithmetic Logic Unit (ALU) and 2's Complement Unit
The ALU is built using modular internal units with gate delay modeling:
* forward_unit: Propagation delay of 1 time unit. Passes DATA2 directly.
* add_unit: Propagation delay of 2 time units. Performs binary addition.
* and_unit: Propagation delay of 1 time unit. Performs bitwise AND.
* or_unit: Propagation delay of 1 time unit. Performs bitwise OR.

Subtraction is performed by computing the 2's complement (~Reg[RS] + 1) with a propagation delay of 1 time unit. Subtraction executes as Reg[RT] + (~Reg[RS] + 1). The zero flag (ZERO) is asserted when the 8-bit ALU result evaluates to zero, which drives conditional branch evaluation.

### 2. Register File
The register file contains 8 8-bit registers (reg_array[7:0]). Reads are asynchronous with a delay of 2 time units. Synchronous writes occur on the rising edge of CLK when the WRITE signal is enabled, featuring a write delay of 1 time unit. A global RESET signal clears all registers to zero.

### 3. Central Control Unit
The control unit decodes opcodes asynchronously with a delay of 1 time unit. It outputs control signals including WRITEENABLE, ALUOP, COMPLEMENT_SELECT, IMMEDIATE_SELECT, JUMP_SIGNAL, BRANCH_SIGNAL, READ, WRITE, and DM_MUX_SELECT. When a cache miss occurs, the BUSYWAIT signal forces WRITEENABLE to 0 and stalls PC updates.

---

## Memory and Cache Subsystem

### 1. Instruction Cache
The instruction cache is a direct-mapped cache of 128 Bytes split into 8 lines, where each line stores 16 Bytes (128 bits or 4 instructions). The 10-bit address from the Program Counter is divided into Tag (bits 9 to 7), Index (bits 6 to 4), and Offset (bits 3 to 0). On a cache miss, the finite state machine stalls the CPU and fetches a 16-Byte block from instruction memory.

### 2. Data Cache
The data cache is a direct-mapped cache of 32 Bytes split into 8 lines, with 4 Bytes per line. It uses a write-back policy with dirty bits and write-allocate on write misses. The 8-bit address is split into Tag (bits 7 to 5), Index (bits 4 to 2), and Offset (bits 1 to 0). The FSM manages hit detection, dirty line evictions to data memory, memory block reading, and cache line updates.

---

## Toolchain and Assembly Flow

1. Assembler (Assembler.c): Translates assembly source code into 32-bit machine code strings.
2. Memory Formatter (generate_memory_image.sh): Formats binary output into Verilog readmemb-compatible files (instr_mem.mem).
3. Simulation Engine (cpu_tb.v): Loads memory image into instruction memory, drives clock and reset signals, and generates GTKWave waveform data (cpu_wavedata.vcd).

---

## Running the Project

### Prerequisites
* Icarus Verilog (iverilog): Verilog simulation compiler.
* GTKWave: Waveform visualization viewer.
* GCC: C compiler for building the assembler.

### Build and Simulation Commands

Compile the assembler and generate memory image:
```bash
gcc Assembler.c -o Assembler
./generate_memory_image.sh program.s
```

Compile and run the testbench:
```bash
iverilog -o cpu_sim cpu_tb.v
vvp cpu_sim
```

Inspect waveforms:
```bash
gtkwave cpu_wavedata.vcd
```

---

## Demonstration Program

The test program (program.s) calculates Fibonacci numbers F(0) to F(8) and stores the resulting array in Data Memory starting from address 0x00:

```assembly
// Calculate Fibonacci Sequence F(0) to F(8)
loadi 1 0x00        // r1 = 0 (F(0))
loadi 2 0x01        // r2 = 1 (F(1))
loadi 3 0x00        // r3 = 0x00 (Memory Pointer)
loadi 4 0x08        // r4 = 8 (Loop Limit)
loadi 5 0x01        // r5 = 1 (Increment)
loadi 6 0x00        // r6 = 0 (Loop Counter)

// Loop Start
swd 1 3             // Mem[r3] = r1 (Store current Fibonacci term)
add 7 1 2           // r7 = r1 + r2 (Compute next term)
mov 1 2             // r1 = r2
mov 2 7             // r2 = r7
add 3 3 5           // r3 = r3 + 1 (Increment pointer)
add 6 6 5           // r6 = r6 + 1 (Increment counter)
beq 0x01 6 4        // Exit loop if r6 == r4
j 0xF8              // Jump back to loop start

swd 1 3             // Store final term F(8) = 21
j 0xFF              // Infinite loop / Halt
```

---

## Repository Structure & Author Credits

| File / Component | Author | Role / Description |
| :--- | :--- | :--- |
| `cpu.v` | F.R. Sujeevan | Top-level CPU core, control unit, and branch/jump logic |
| `alu.v` | F.R. Sujeevan | Modular ALU, sub-units, 2's complement, and zero flag |
| `reg.v` | F.R. Sujeevan | 8x8-bit register file with asynchronous reads |
| `icache.v` | F.R. Sujeevan | 128-Byte direct-mapped instruction cache & miss FSM |
| `dcache.v` | F.R. Sujeevan | 32-Byte direct-mapped write-back data cache |
| `cpu_tb.v` | F.R. Sujeevan | Simulation testbench driver |
| `instruction_memory.v` | Isuru Nawinne | 1024-Byte instruction memory module (CO2070 course module) |
| `dmem_for_dcache.v` | Isuru Nawinne | 256-Byte data memory module (CO2070 course module) |
| `Assembler.c` | Isuru Nawinne | C-based ISA assembler tool (CO2070 course tool) |
| `generate_memory_image.sh` | Kisaru Liyanage | Memory formatting script for Verilog $readmemb |

---

## Acknowledgments and References

* Reference Textbook: *Computer Organization and Design: The Hardware/Software Interface, Sixth Edition*, by David A. Patterson and John L. Hennessy.
* Course Context: CO2070 Computer Architecture laboratory series, Department of Computer Engineering, University of Peradeniya.

---

## Author

F.R. Sujeevan  
Second-Year Computer Engineering Undergraduate, Department of Computer Engineering, University of Peradeniya.
