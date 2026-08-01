`timescale 1ns/100ps

`include "alu.v"
`include "reg.v"
`include "dcache.v"
`include "icache.v"

module cpu(PC, INSTRUCTION, CLK, RESET);
    input CLK, RESET;
    output [31:0] INSTRUCTION;
    output reg [31:0] PC;

    // opcode parameters
    parameter [7:0] OP_LOADI    = 8'b00000000;
    parameter [7:0] OP_MOV      = 8'b00000001;
    parameter [7:0] OP_ADD      = 8'b00000010;
    parameter [7:0] OP_SUB      = 8'b00000011;
    parameter [7:0] OP_AND      = 8'b00000100;
    parameter [7:0] OP_OR       = 8'b00000101;
    parameter [7:0] OP_JUMP     = 8'b00000110;
    parameter [7:0] OP_BEQ      = 8'b00000111;
    parameter [7:0] OP_LWD      = 8'b00001000;
    parameter [7:0] OP_LWI      = 8'b00001001;
    parameter [7:0] OP_SWD      = 8'b00001010;
    parameter [7:0] OP_SWI      = 8'b00001011;

    // ALU parameters to select the operation
    parameter [2:0] ALU_FORWARD = 3'b000;
    parameter [2:0] ALU_ADD     = 3'b001;
    parameter [2:0] ALU_AND     = 3'b010;
    parameter [2:0] ALU_OR      = 3'b011;

    // instruction decoding
    wire [7:0] OPCODE;
    wire [7:0] RD;
    wire [7:0] RT;
    wire [7:0] RS;

    assign OPCODE = INSTRUCTION[31:24];
    assign RD     = INSTRUCTION[23:16];
    assign RT     = INSTRUCTION[15:8];
    assign RS     = INSTRUCTION[7:0];

    // Register File wiring
    wire [2:0] WRITEREG;
    wire [2:0] READREG1;
    wire [2:0] READREG2;

    assign WRITEREG = RD[2:0];
    assign READREG1 = RT[2:0];
    assign READREG2 = RS[2:0];

    wire [7:0] REGOUT1;
    wire [7:0] REGOUT2;

    reg WRITEENABLE;

    // ALU wiring
    wire [7:0] ALURESULT;
    wire ZERO;
    reg [2:0] ALUOP;

    // Immediate values
    wire [7:0] IMMEDIATE;
    assign IMMEDIATE = RS;

    // Combined Busywait signal
    wire BUSYWAIT;
    wire DCACHE_BUSYWAIT;
    wire ICACHE_BUSYWAIT;

    assign BUSYWAIT = DCACHE_BUSYWAIT || ICACHE_BUSYWAIT;

    // Register File Instance
    reg_file my_reg_file(
        DM_MUX,        // IN
        REGOUT1,       // OUT1
        REGOUT2,       // OUT2
        WRITEREG,      // INADDRESS
        READREG1,      // OUT1ADDRESS
        READREG2,      // OUT2ADDRESS
        WRITEENABLE, 
        CLK,
        RESET
    );

    // 2's complement logic
    wire [7:0] COMP_REGOUT2;
    assign #1 COMP_REGOUT2 = ~REGOUT2 + 8'b00000001;

    reg COMPLEMENT_SELECT;
    reg IMMEDIATE_SELECT;

    wire [7:0] COMP_MUX_OUT;
    assign COMP_MUX_OUT = (COMPLEMENT_SELECT == 1'b1) ? COMP_REGOUT2 : REGOUT2;

    wire [7:0] ALU_DATA2;
    assign ALU_DATA2 = (IMMEDIATE_SELECT == 1'b1) ? IMMEDIATE : COMP_MUX_OUT;

    // ALU Instance
    alu my_alu(
        REGOUT1,
        ALU_DATA2,
        ALURESULT,
        ALUOP,
        ZERO
    );

    // Flow control (Branch & Jump)
    wire signed [7:0] BRANCH_OFFSET;
    assign BRANCH_OFFSET = RD;

    wire [31:0] PC_PLUS_4;
    assign #1 PC_PLUS_4 = PC + 32'd4;

    wire [31:0] BRANCH_TARGET;
    wire [31:0] OFFSET_EXTENDED;
    wire [31:0] OFFSET_SHIFTED;

    assign OFFSET_EXTENDED = {{24{BRANCH_OFFSET[7]}}, BRANCH_OFFSET};
    assign OFFSET_SHIFTED = OFFSET_EXTENDED << 2;
    assign #2 BRANCH_TARGET = PC_PLUS_4 + OFFSET_SHIFTED;

    wire [31:0] NEXT_PC;
    assign NEXT_PC = (OR_SIGNAL) ? BRANCH_TARGET : PC_PLUS_4;

    reg BRANCH_SIGNAL;
    reg JUMP_SIGNAL;

    wire OR_SIGNAL;
    wire AND_SIGNAL;

    assign AND_SIGNAL = (BRANCH_SIGNAL && ZERO);
    assign OR_SIGNAL = (AND_SIGNAL || JUMP_SIGNAL);

    // Data Memory / Data Cache Control Signals
    reg READ;
    reg WRITE;
    reg DM_MUX_SELECT;

    wire [7:0] READDATA;
    wire [7:0] DM_MUX;

    // Instruction Cache Instance
    icache inst_cache (
        .clock(CLK),
        .reset(RESET),
        .address(PC[9:0]),
        .readinst(INSTRUCTION),
        .busywait(ICACHE_BUSYWAIT)
    );

    // Data Cache Instance
    dcache data_cache (
        .clock(CLK),
        .reset(RESET),
        .read(READ),
        .write(WRITE),
        .address(ALURESULT),
        .writedata(REGOUT1),
        .readdata(READDATA),
        .busywait(DCACHE_BUSYWAIT)
    );

    // Data Memory MUX: selects between ALU Result and Data Cache Read Data
    assign DM_MUX = (DM_MUX_SELECT) ? READDATA : ALURESULT;

    // Control Unit
    always @(*) begin
        #1;
        WRITEENABLE = 1'b0;
        ALUOP = ALU_FORWARD;
        COMPLEMENT_SELECT = 1'b0;
        IMMEDIATE_SELECT = 1'b0;
        JUMP_SIGNAL = 1'b0;
        BRANCH_SIGNAL = 1'b0;

        READ = 1'b0;
        WRITE = 1'b0;
        DM_MUX_SELECT = 1'b0;

        if (!BUSYWAIT) begin
            case (OPCODE)
                OP_LOADI: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    ALUOP = ALU_FORWARD;
                    IMMEDIATE_SELECT = 1'b1;
                end

                OP_MOV: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    ALUOP = ALU_FORWARD;
                    IMMEDIATE_SELECT = 1'b0;
                end

                OP_ADD: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_ADD;
                end

                OP_SUB: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b1;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_ADD;
                end

                OP_AND: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_AND;
                end
                
                OP_OR: begin
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_OR;
                end

                OP_JUMP: begin 
                    WRITEENABLE = 1'b0;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_FORWARD;
                    JUMP_SIGNAL = 1'b1;
                end

                OP_BEQ: begin 
                    WRITEENABLE = 1'b0;
                    COMPLEMENT_SELECT = 1'b1;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_ADD;
                    BRANCH_SIGNAL = 1'b1;
                    JUMP_SIGNAL = 1'b0;
                end

                OP_LWD: begin 
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_FORWARD;
                    WRITE = 1'b0;
                    READ = 1'b1;
                    DM_MUX_SELECT = 1'b1;
                end

                OP_LWI: begin 
                    WRITEENABLE = 1'b1;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b1;
                    ALUOP = ALU_FORWARD;
                    WRITE = 1'b0;
                    READ = 1'b1;
                    DM_MUX_SELECT = 1'b1;
                end

                OP_SWD: begin 
                    WRITEENABLE = 1'b0;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b0;
                    ALUOP = ALU_FORWARD;
                    WRITE = 1'b1;
                    READ = 1'b0;
                    DM_MUX_SELECT = 1'b0;
                end

                OP_SWI: begin 
                    WRITEENABLE = 1'b0;
                    COMPLEMENT_SELECT = 1'b0;
                    IMMEDIATE_SELECT = 1'b1;
                    ALUOP = ALU_FORWARD;
                    WRITE = 1'b1;
                    READ = 1'b0;
                    DM_MUX_SELECT = 1'b0;
                end

                default: begin 
                    WRITEENABLE = 1'b0;
                end

            endcase
        end
        else begin
            // Stall condition: hold memory access requests and disable register writes
            WRITEENABLE = 1'b0;
        end
    end

    // Program Counter Update Logic
    always @(posedge CLK) begin
        if (RESET) begin
            PC <= #1 32'd0;
        end
        else if (BUSYWAIT) begin 
            // Stall PC when either cache is busywaiting
            PC <= #1 PC;
        end
        else begin
            PC <= #1 NEXT_PC;
        end
    end

endmodule
