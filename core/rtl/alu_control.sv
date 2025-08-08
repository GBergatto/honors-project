/* verilator lint_off IMPORTSTAR */
import core_types_pkg::*;

module alu_control (
   input logic [2:0] funct3,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [6:0] funct7,
   output alu_op_t alu_op
);

always_comb begin
   unique case (funct3)
      3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
      3'b001: alu_op = ALU_SLL;
      3'b010: alu_op = ALU_SLT;
      3'b011: alu_op = ALU_SLTU;
      3'b100: alu_op = ALU_XOR;
      3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
      3'b110: alu_op = ALU_OR;
      3'b111: alu_op = ALU_AND;
   endcase
end

endmodule
