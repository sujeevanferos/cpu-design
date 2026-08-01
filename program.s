// Assembly program: Fibonacci Sequence Calculation
// Calculates Fibonacci numbers F(0) to F(8) and stores them in Data Memory (0x00 to 0x08).

loadi 1 0x00        // r1 = 0 (first Fibonacci term, F(0))
loadi 2 0x01        // r2 = 1 (second Fibonacci term, F(1))
loadi 3 0x00        // r3 = 0 (memory address pointer, starts at 0x00)
loadi 4 0x08        // r4 = 8 (loop limit, compute up to F(8))
loadi 5 0x01        // r5 = 1 (constant increment for pointer and counter)
loadi 6 0x00        // r6 = 0 (loop counter, counts 0 to 8)
swd 1 3             // Mem[r3] = r1; store current Fibonacci term to data memory
add 7 1 2           // r7 = r1 + r2; compute next Fibonacci term
mov 1 2             // r1 = r2; shift current term to previous
mov 2 7             // r2 = r7; shift next term to current
add 3 3 5           // r3 = r3 + 1; increment memory pointer
add 6 6 5           // r6 = r6 + 1; increment loop counter
beq 0x01 6 4        // if r6 == r4 (counter == 8), skip next instruction (exit loop)
j 0xF8              // jump back to swd (loop start at PC=24, offset = -8 instructions)
swd 1 3             // Mem[r3] = r1; store final Fibonacci term F(8) = 21
j 0xFF              // halt (infinite loop to self)
