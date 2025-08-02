/* verilator lint_off IMPORTSTAR */
import core_types_pkg::*;

module alu (
    input logic signed [31:0] op1,
    input logic signed [31:0] op2,
    input alu_op_t alu_op,
    output logic [31:0] out
);

always_comb begin
   case (alu_op)
      ALU_ADD: out = op1 + op2;
      ALU_SUB: out = op1 - op2;
      ALU_SLL: out = op1 << op2[4:0];
      ALU_SLT: out = (op1 < op2) ? 1 : 0;
      ALU_SLTU: out = ($unsigned(op1) < $unsigned(op2)) ? 1 : 0;
      ALU_XOR: out = op1 ^ op2;
      ALU_SRL: out = op1 >> op2[4:0];
      ALU_SRA: out = op1 >>> op2[4:0];
      ALU_OR: out = op1 | op2;
      ALU_AND: out = op1 & op2;
      default: out = 0;
   endcase
end

endmodule
