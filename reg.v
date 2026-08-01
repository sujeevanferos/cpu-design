// Author: F.R. Sujeevan
// register file

`timescale 1ns/100ps

module reg_file(IN,OUT1,OUT2,INADDRESS,OUT1ADDRESS,OUT2ADDRESS, WRITE, CLK, RESET);

    input [7:0] IN;
    input [2:0] INADDRESS;
    input [2:0] OUT1ADDRESS;
    input [2:0] OUT2ADDRESS;

    input WRITE;
    input CLK;
    input RESET;

    output reg [7:0] OUT1;
    output reg [7:0] OUT2;


    reg [7:0] reg_array [7:0];
    integer i;

    // debug wires for cpu
    wire [7:0] r0 = reg_array[0];
    wire [7:0] r1 = reg_array[1];
    wire [7:0] r2 = reg_array[2];
    wire [7:0] r3 = reg_array[3];
    wire [7:0] r4 = reg_array[4];
    wire [7:0] r5 = reg_array[5];
    wire [7:0] r6 = reg_array[6];
    wire [7:0] r7 = reg_array[7];

    always @(posedge CLK)
    begin
        if (RESET) begin
            for (i = 0; i < 8; i = i + 1)
                reg_array[i] <= #1 8'b00000000;
        end

        else if (WRITE) begin
            reg_array[INADDRESS] <= #1 IN;
        end
    end
 
    always @(*) begin
        OUT1 = #2 reg_array[OUT1ADDRESS];
    end

    always @(*) begin
        OUT2 = #2 reg_array[OUT2ADDRESS];
    end

endmodule
