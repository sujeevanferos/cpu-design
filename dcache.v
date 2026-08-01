`timescale 1ns/100ps

`include "dmem_for_dcache.v"

/*
Module      : Data Cache (dcache)
Author      : F.R. Sujeevan (E/22/382)
Description : CO2070 Lab 6/7 data cache module.
              CPU side uses 8-bit byte access.
              Memory side uses 32-bit block access.
*/

module dcache(
    clock,
    reset,

    // CPU side signals
    read,
    write,
    address,
    writedata,
    readdata,
    busywait
);

input clock;
input reset;

// CPU side
input read;
input write;
input [7:0] address;
input [7:0] writedata;
output reg [7:0] readdata;
output reg busywait;

// Memory side internal signals
wire mem_read;
wire mem_write;
wire [5:0] mem_address;
wire [31:0] mem_writedata;
wire [31:0] mem_readdata;
wire mem_busywait;

reg mem_read_reg;
reg mem_write_reg;
reg [5:0] mem_address_reg;
reg [31:0] mem_writedata_reg;

assign mem_read      = mem_read_reg;
assign mem_write     = mem_write_reg;
assign mem_address   = mem_address_reg;
assign mem_writedata = mem_writedata_reg;

// Instantiate data_memory module inside data cache
data_memory dmem(
    clock,
    reset,
    mem_read,
    mem_write,
    mem_address,
    mem_writedata,
    mem_readdata,
    mem_busywait
);

// --------------------------------------------------
// Address split
// --------------------------------------------------
// 8-bit CPU address = TAG + INDEX + OFFSET
// TAG    = address[7:5]
// INDEX  = address[4:2]
// OFFSET = address[1:0]

wire [2:0] tag;
wire [2:0] index;
wire [1:0] offset;

assign tag    = address[7:5];
assign index  = address[4:2];
assign offset = address[1:0];

// --------------------------------------------------
// Cache storage
// --------------------------------------------------
reg [31:0] data_array  [7:0];
reg [2:0]  tag_array   [7:0];
reg        valid_array [7:0];
reg        dirty_array [7:0];

// --------------------------------------------------
// Selected cache line extraction
// --------------------------------------------------
reg [31:0] selected_block;
reg [2:0]  selected_tag;
reg        selected_valid;
reg        selected_dirty;

always @(*)
begin
    #1;
    selected_block = data_array[index];
    selected_tag   = tag_array[index];
    selected_valid = valid_array[index];
    selected_dirty = dirty_array[index];
end

// --------------------------------------------------
// Hit detection
// --------------------------------------------------
wire hit;
assign #0.9 hit = (selected_valid && (selected_tag == tag));

// --------------------------------------------------
// Byte selection from selected cache block
// --------------------------------------------------
reg [7:0] selected_byte;

always @(*)
begin
    #1;
    case (offset)
        2'b00: selected_byte = selected_block[7:0];
        2'b01: selected_byte = selected_block[15:8];
        2'b10: selected_byte = selected_block[23:16];
        2'b11: selected_byte = selected_block[31:24];
        default: selected_byte = 8'b0;
    endcase
end

// --------------------------------------------------
// Access type
// --------------------------------------------------
wire readaccess;
wire writeaccess;
wire readhit;
wire writehit;
wire miss;

assign readaccess  = read && !write;
assign writeaccess = !read && write;

assign readhit  = readaccess && hit;
assign writehit = writeaccess && hit;

assign miss = (readaccess || writeaccess) && !hit;

// --------------------------------------------------
// FSM state declaration
// --------------------------------------------------
parameter IDLE         = 3'b000;
parameter MEM_WRITE    = 3'b001;
parameter MEM_GAP      = 3'b010;
parameter MEM_READ     = 3'b011;
parameter CACHE_UPDATE = 3'b100;

reg [2:0] state;
reg [2:0] next_state;

// --------------------------------------------------
// State register and cache write/update logic
// --------------------------------------------------
integer i;

always @(posedge clock or posedge reset)
begin
    if (reset)
    begin
        state <= IDLE;

        for (i = 0; i < 8; i = i + 1)
        begin
            data_array[i]  = 32'b0;
            tag_array[i]   = 3'b000;
            valid_array[i] = 1'b0;
            dirty_array[i] = 1'b0;
        end
    end
    else
    begin
        state <= next_state;

        // Write hit: update selected byte in cache.
        if ((state == IDLE) && writehit)
        begin
            #1;
            case (offset)
                2'b00: data_array[index][7:0]   = writedata;
                2'b01: data_array[index][15:8]  = writedata;
                2'b10: data_array[index][23:16] = writedata;
                2'b11: data_array[index][31:24] = writedata;
            endcase

            valid_array[index] = 1'b1;
            dirty_array[index] = 1'b1;
        end

        // Cache update after memory read miss.
        if (state == CACHE_UPDATE)
        begin
            #1;

            // Store fetched block into cache.
            data_array[index]  = mem_readdata;
            tag_array[index]   = tag;
            valid_array[index] = 1'b1;
            dirty_array[index] = 1'b0;

            // If original request was write miss, update byte
            if (writeaccess)
            begin
                case (offset)
                    2'b00: data_array[index][7:0]   = writedata;
                    2'b01: data_array[index][15:8]  = writedata;
                    2'b10: data_array[index][23:16] = writedata;
                    2'b11: data_array[index][31:24] = writedata;
                endcase

                dirty_array[index] = 1'b1;
            end
        end
    end
end

// --------------------------------------------------
// Read data output
// --------------------------------------------------
always @(*)
begin
    if (readhit)
    begin
        readdata = selected_byte;
    end
    else
    begin
        readdata = 8'bx;
    end
end

// --------------------------------------------------
// Next-state logic
// --------------------------------------------------
always @(*)
begin
    next_state = state;

    case (state)

        IDLE:
        begin
            if (miss)
            begin
                if (selected_valid && selected_dirty)
                begin
                    next_state = MEM_WRITE;
                end
                else
                begin
                    next_state = MEM_READ;
                end
            end
            else
            begin
                next_state = IDLE;
            end
        end

        MEM_WRITE:
        begin
            if (!mem_busywait)
            begin
                next_state = MEM_GAP;
            end
            else
            begin
                next_state = MEM_WRITE;
            end
        end

        MEM_GAP:
        begin
            next_state = MEM_READ;
        end

        MEM_READ:
        begin
            if (!mem_busywait)
            begin
                next_state = CACHE_UPDATE;
            end
            else
            begin
                next_state = MEM_READ;
            end
        end

        CACHE_UPDATE:
        begin
            next_state = IDLE;
        end

        default:
        begin
            next_state = IDLE;
        end

    endcase
end

// --------------------------------------------------
// FSM output logic
// --------------------------------------------------
always @(*)
begin
    mem_read_reg      = 1'b0;
    mem_write_reg     = 1'b0;
    mem_address_reg   = 6'bxxxxxx;
    mem_writedata_reg = 32'bx;
    busywait          = 1'b0;

    case (state)

        IDLE:
        begin
            mem_read_reg  = 1'b0;
            mem_write_reg = 1'b0;

            if (!read && !write)
            begin
                busywait = 1'b0;
            end
            else if (hit)
            begin
                busywait = 1'b0;
            end
            else
            begin
                busywait = 1'b1;
            end
        end

        MEM_WRITE:
        begin
            mem_read_reg      = 1'b0;
            mem_write_reg     = 1'b1;
            mem_address_reg   = {selected_tag, index};
            mem_writedata_reg = selected_block;
            busywait          = 1'b1;
        end

        MEM_GAP:
        begin
            mem_read_reg      = 1'b0;
            mem_write_reg     = 1'b0;
            mem_address_reg   = 6'bxxxxxx;
            mem_writedata_reg = 32'bx;
            busywait          = 1'b1;
        end

        MEM_READ:
        begin
            mem_read_reg      = 1'b1;
            mem_write_reg     = 1'b0;
            mem_address_reg   = {tag, index};
            mem_writedata_reg = 32'bx;
            busywait          = 1'b1;
        end

        CACHE_UPDATE:
        begin
            mem_read_reg      = 1'b0;
            mem_write_reg     = 1'b0;
            mem_address_reg   = 6'bxxxxxx;
            mem_writedata_reg = 32'bx;
            busywait          = 1'b1;
        end

        default:
        begin
            mem_read_reg      = 1'b0;
            mem_write_reg     = 1'b0;
            mem_address_reg   = 6'bxxxxxx;
            mem_writedata_reg = 32'bx;
            busywait          = 1'b0;
        end

    endcase
end

endmodule
