`timescale 1ns/100ps

`include "cpu.v"

module cpu_tb;

    reg CLK, RESET;
    wire [31:0] PC;
    wire [31:0] INSTRUCTION;

    /*
      CPU MODULE INSTANCE
    Integrated CPU module containing both Instruction Cache (icache)
    and Data Cache (dcache).
    */
    cpu mycpu(
        .PC(PC),
        .INSTRUCTION(INSTRUCTION),
        .CLK(CLK),
        .RESET(RESET)
    );

    initial
    begin
        // Generate waveform file for GTKWave analysis
        $dumpfile("cpu_wavedata.vcd");
        $dumpvars(0, cpu_tb);

        CLK = 1'b0;
        RESET = 1'b0;

        // Load program into instruction memory from external .mem file
        $readmemb("instr_mem.mem", mycpu.inst_cache.imem.memory_array);

        // Reset the CPU (giving a pulse to RESET signal)
        #5 RESET = 1'b1;  // Assert reset
        #10 RESET = 1'b0; // De-assert reset

        // Run simulation long enough to observe instruction cache misses/hits & data cache operations
        #5000;
        $finish;
    end

    // Clock signal generation (Period = 8 time units)
    always
        #4 CLK = ~CLK;

endmodule
