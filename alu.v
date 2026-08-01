//Author: F.R. Sujeevan
//This file is for ALU design of Lab2

`timescale 1ns/100ps

module forward_unit (
    input [7:0] DATA2,
    output [7:0] RESULT
);

    assign #1 RESULT = DATA2;

endmodule


module add_unit (
    input [7:0] DATA1,
    input [7:0] DATA2,
    output [7:0] RESULT
);

    assign #2 RESULT = DATA1 + DATA2;

endmodule

module and_unit (
    input [7:0] DATA1,
    input [7:0] DATA2,
    output [7:0] RESULT
);

    assign #1 RESULT = DATA1 & DATA2;

endmodule

module or_unit (
    input [7:0] DATA1,
    input [7:0] DATA2,
    output [7:0] RESULT
);

    assign #1 RESULT = DATA1 | DATA2;

endmodule

module alu (DATA1, DATA2, RESULT, SELECT, ZERO);

    // the input wires for the ALU
    input [7:0] DATA1;
    input [7:0] DATA2;

    // the specific values for SELECT should make the mux to output different values of RESULT
    // according to the selected modules!
    output reg [7:0] RESULT;
    output wire ZERO;  // ZERO flag indicates if ALU result is zero (used for beq instruction)
    input [2:0] SELECT;

    // internal wires
    wire [7:0] forward_out;
    wire [7:0] add_out;
    wire [7:0] and_out;
    wire [7:0] or_out;

    forward_unit FORWARD_U (
        .DATA2 (DATA2),
        .RESULT (forward_out)
    );

    add_unit ADD_U (
        .DATA1 (DATA1),
        .DATA2 (DATA2),
        .RESULT (add_out)
    );

    and_unit AND_U (
        .DATA1 (DATA1),
        .DATA2 (DATA2),
        .RESULT (and_out)
    );

    or_unit OR_U (
        .DATA1 (DATA1),
        .DATA2 (DATA2),
        .RESULT (or_out)
    );


    //mux
    always @(*) begin
        case (SELECT)
            3'b000 : RESULT = forward_out;
            3'b001 : RESULT = add_out;
            3'b010 : RESULT = and_out;
            3'b011 : RESULT = or_out;

            default : RESULT = 8'b00000000;
        endcase

    end

    // ZERO flag: asserted when alu result is zero (used for beq instruction)
    assign #1 ZERO = (RESULT == 8'b00000000) ? 1'b1 : 1'b0;

endmodule
