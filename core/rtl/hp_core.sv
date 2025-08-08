module hp_core (
    input logic clk
);

/* Program Counter */
logic [29:0] pc; // no low 2 bits because we're only addressing 32-bit instructions
initial begin
  pc = 0;
end

always_ff @(posedge clk) begin
   pc <= pc + 1;
end

/* Instruction Memory */
logic [31:0] inst;
imem #(8) imem_i (
   .clk (clk),
   .pc (pc),
   .inst (inst)
);

/* Immediate Generator */
logic [31:0] imm;
immgen immgen_i (
   .inst (inst),
   .imm (imm)
);

/* Decoder */
logic [6:0] opcode;
logic [4:0] rd;
logic [2:0] funct3;
logic [4:0] rs1;
logic [4:0] rs2;
logic [6:0] funct7;

always_comb begin
   opcode = inst[6:0];
   rd     = inst[11:7];
   funct3 = inst[14:12];
   rs1    = inst[19:15];
   rs2    = inst[24:20];
   funct7 = inst[31:25];
end

/* Control Logic */
control control_i (
   .opcode (opcode),
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_src (alu_src),
   .reg_write (reg_write)
);

/* Register File */
logic reg_write;
logic [31:0] rs1_data, rs2_data;
regfile regfile_i (
   .clk (clk),
   .rs1 (rs1),
   .rs2 (rs2),
   .rd (rd),
   .rd_data (alu_out),
   .write (reg_write),
   .rs1_data (rs1_data),
   .rs2_data (rs2_data)
);

/* ALU */
logic [31:0] y, alu_out;
logic alu_src;
alu_op_t alu_op;
assign y = (alu_src) ? imm : rs2_data;

alu_control alu_control_i (
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_op (alu_op)
);

alu alu_i (
   .op1 (rs1_data),
   .op2 (y),
   .alu_op (alu_op),
   .out (alu_out)
);

endmodule

