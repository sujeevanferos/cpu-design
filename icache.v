`timescale 1ns/100ps

`include "instruction_memory.v"

/*
Module      : Instruction Cache (icache)
Author      : F.R. Sujeevan
Description : Instruction Cache module.
              - Cache Size       : 128 Bytes
              - Block Size       : 16 Bytes (128 bits / 4 instruction words)
              - Block Placement  : Direct-mapped (8 blocks total)
              - Replacement      : Read-only, no dirty bit / write-back required
              - Addressing       : 10-bit address space
                                   Tag    = address[9:7] (3 bits)
                                   Index  = address[6:4] (3 bits)
                                   Offset = address[3:0] (4 bits)
              - Latencies        :
                                   Indexing delay          = #1 time unit
                                   Tag comparison delay    = #0.9 time units
                                   Word selection delay    = #1 time unit (parallel to tag comparison)
                                   Cache line write delay  = #1 time unit
                                   Instruction miss penalty= 81 CPU cycles
*/

module icache(
    clock,
    reset,

    // CPU side signals
    address,        // 10-bit address from CPU Program Counter
    readinst,       // 32-bit fetched instruction word to CPU
    busywait        // Busywait signal to CPU (stalls CPU on icache miss)
);

input clock;
input reset;

// CPU side
input [9:0] address;
output reg [31:0] readinst;
output reg busywait;

// Instruction Memory interface signals
wire mem_read;
wire [5:0] mem_address;
wire [127:0] mem_readinst;
wire mem_busywait;

reg mem_read_reg;
reg [5:0] mem_address_reg;

assign mem_read    = mem_read_reg;
assign mem_address = mem_address_reg;

// Instantiate instruction_memory module inside instruction cache
instruction_memory imem(
    .clock(clock),
    .read(mem_read),
    .address(mem_address),
    .readinst(mem_readinst),
    .busywait(mem_busywait)
);

// --------------------------------------------------
// Address Split
// --------------------------------------------------
// 10-bit instruction address = TAG + INDEX + OFFSET
// TAG    = address[9:7]  (3 bits)
// INDEX  = address[6:4]  (3 bits)
// OFFSET = address[3:0]  (4 bits)

wire [2:0] tag;
wire [2:0] index;
wire [3:0] offset;

assign tag    = address[9:7];
assign index  = address[6:4];
assign offset = address[3:0];

// --------------------------------------------------
// Cache Storage Arrays
// --------------------------------------------------
// 8 cache lines (direct-mapped).
// Each line has a 16-Byte (128-bit) block, 3-bit tag, and 1 valid bit.

reg [127:0] data_array  [7:0];
reg [2:0]   tag_array   [7:0];
reg         valid_array [7:0];

// --------------------------------------------------
// Selected Cache Line Extraction
// --------------------------------------------------
// Artificial indexing latency of #1 time unit.

reg [127:0] selected_block;
reg [2:0]   selected_tag;
reg         selected_valid;

always @(*)
begin
    #1;
    selected_block = data_array[index];
    selected_tag   = tag_array[index];
    selected_valid = valid_array[index];
end

// --------------------------------------------------
// Hit Detection
// --------------------------------------------------
// Tag comparison & validation latency of #0.9 time units.
// Total hit detection latency = #1.0 (indexing) + #0.9 (comparison) = #1.9 time units.

wire hit;

assign #0.9 hit = (selected_valid && (selected_tag == tag));

// --------------------------------------------------
// Instruction Word Selection from 16-Byte Block
// --------------------------------------------------
// Artificial word selection latency of #1 time unit.
// Note: This selection latency runs in parallel to tag comparison.

reg [31:0] selected_word;

always @(*)
begin
    #1;
    case (offset[3:2])
        2'b00: selected_word = selected_block[31:0];
        2'b01: selected_word = selected_block[63:32];
        2'b10: selected_word = selected_block[95:64];
        2'b11: selected_word = selected_block[127:96];
        default: selected_word = 32'bx;
    endcase
end

// --------------------------------------------------
// Read Instruction Output
// --------------------------------------------------
// On hit: send selected 32-bit instruction word to CPU.
// On miss: output is unknown while CPU is stalled.

always @(*)
begin
    if (hit)
    begin
        readinst = selected_word;
    end
    else
    begin
        readinst = 32'bx;
    end
end

// --------------------------------------------------
// FSM State Declaration
// --------------------------------------------------

parameter IDLE         = 2'b00;
parameter MEM_READ     = 2'b01;
parameter CACHE_UPDATE = 2'b10;

reg [1:0] state;
reg [1:0] next_state;

// --------------------------------------------------
// Sequential State Register & Cache Update Logic
// --------------------------------------------------

integer i;

always @(posedge clock or posedge reset)
begin
    if (reset)
    begin
        state <= IDLE;

        // Reset all valid bits to 0 (cache is empty at startup)
        for (i = 0; i < 8; i = i + 1)
        begin
            data_array[i]  = 128'b0;
            tag_array[i]   = 3'b000;
            valid_array[i] = 1'b0;
        end
    end
    else
    begin
        state <= next_state;

        // On CACHE_UPDATE state, write fetched 16-Byte block into cache line.
        // Include #1 artificial latency for writing to cache.
        if (state == CACHE_UPDATE)
        begin
            #1;
            data_array[index]  = mem_readinst;
            tag_array[index]   = tag;
            valid_array[index] = 1'b1;
        end
    end
end

// --------------------------------------------------
// Combinational Next-State Logic
// --------------------------------------------------

always @(*)
begin
    next_state = state;

    case (state)

        IDLE:
        begin
            if (!hit)
            begin
                // Cache miss: move to MEM_READ to fetch missing block
                next_state = MEM_READ;
            end
            else
            begin
                next_state = IDLE;
            end
        end

        MEM_READ:
        begin
            if (!mem_busywait)
            begin
                // Memory block read complete: move to CACHE_UPDATE
                next_state = CACHE_UPDATE;
            end
            else
            begin
                next_state = MEM_READ;
            end
        end

        CACHE_UPDATE:
        begin
            // Cache line updated: return to IDLE for asynchronous hit serving
            next_state = IDLE;
        end

        default:
        begin
            next_state = IDLE;
        end

    endcase
end

// --------------------------------------------------
// FSM Output Logic
// --------------------------------------------------

always @(*)
begin
    // Default assignments
    mem_read_reg    = 1'b0;
    mem_address_reg = 6'bxxxxxx;
    busywait        = 1'b0;

    case (state)

        IDLE:
        begin
            mem_read_reg = 1'b0;

            if (hit)
            begin
                busywait = 1'b0;
            end
            else
            begin
                // Miss detected: assert busywait to stall CPU
                busywait = 1'b1;
            end
        end

        MEM_READ:
        begin
            // Fetch missing 16-Byte block from instruction memory
            mem_read_reg    = 1'b1;
            mem_address_reg = {tag, index}; // 6-bit block address
            busywait        = 1'b1;
        end

        CACHE_UPDATE:
        begin
            mem_read_reg    = 1'b0;
            mem_address_reg = 6'bxxxxxx;
            busywait        = 1'b1;
        end

        default:
        begin
            mem_read_reg    = 1'b0;
            mem_address_reg = 6'bxxxxxx;
            busywait        = 1'b0;
        end

    endcase
end

endmodule
