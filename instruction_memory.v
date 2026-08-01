`timescale 1ns/100ps

/*
Module	: 256x8-bit instruction memory (16-Byte blocks)
Author	: Isuru Nawinne
Date	: 10/06/2020

Description :
This file presents an instruction memory module for CO2070 Lab 7.
This memory allows instructions to be read as 16-Byte blocks.
*/

module instruction_memory(
    clock,
    read,
    address,
    readinst,
    busywait
);
input               clock;
input               read;
input[5:0]          address;
output reg [127:0]  readinst;
output reg          busywait;

reg readaccess;

// Declare memory array 1024x8-bits (1024 Bytes)
reg [7:0] memory_array [0:1023];

integer i;

// Initialize instruction memory
initial
begin
    busywait = 0;
    readaccess = 0;

    // Reset memory array
    for (i = 0; i < 1024; i = i + 1)
        memory_array[i] = 8'b0;
end

// Detecting an incoming memory access
always @(read)
begin
    busywait = (read)? 1 : 0;
    readaccess = (read)? 1 : 0;
end

// Reading 16-Byte block with artificial delay
always @(posedge clock)
begin
    if(readaccess)
    begin
        readinst[7:0]     = #40 memory_array[{address,4'b0000}];
        readinst[15:8]    = #40 memory_array[{address,4'b0001}];
        readinst[23:16]   = #40 memory_array[{address,4'b0010}];
        readinst[31:24]   = #40 memory_array[{address,4'b0011}];
        readinst[39:32]   = #40 memory_array[{address,4'b0100}];
        readinst[47:40]   = #40 memory_array[{address,4'b0101}];
        readinst[55:48]   = #40 memory_array[{address,4'b0110}];
        readinst[63:56]   = #40 memory_array[{address,4'b0111}];
        readinst[71:64]   = #40 memory_array[{address,4'b1000}];
        readinst[79:72]   = #40 memory_array[{address,4'b1001}];
        readinst[87:80]   = #40 memory_array[{address,4'b1010}];
        readinst[95:88]   = #40 memory_array[{address,4'b1011}];
        readinst[103:96]  = #40 memory_array[{address,4'b1100}];
        readinst[111:104] = #40 memory_array[{address,4'b1101}];
        readinst[119:112] = #40 memory_array[{address,4'b1110}];
        readinst[127:120] = #40 memory_array[{address,4'b1111}];
        busywait = 0;
        readaccess = 0;
    end
end

endmodule
