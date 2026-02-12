module control (
   input logic [6:0] opcode,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [2:0] funct3,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [6:0] funct7,
   output logic alu_src,
   output logic reg_write,
   output logic mem_write,
   output logic mem_read,
   output logic [1:0] result_src,
   output logic branch,
   output logic jump,
   output logic jump_reg
);

// ALU source op2 is Immediate for everything except R-Types and Branches
assign alu_src = (opcode != 7'b0110011) && (opcode != 7'b1100011);

always_comb begin
   case (opcode)
      7'b1100011, // branch
      7'b0100011: // store
         reg_write = 1'b0;
      default:
         reg_write = 1'b1;
   endcase
end

assign mem_write = (opcode == 7'b0100011);
assign mem_read = (opcode == 7'b0000011);
always_comb begin
   case (opcode)
      7'b1101111, // JAL
      7'b1100111: // JALR
         result_src = 2'b10;
      7'b0000011: // load
         result_src = 2'b01;
      default: result_src = 2'b00;
   endcase
end

assign jump = (opcode == 7'b1101111 || opcode == 7'b1100111);
assign branch = (opcode == 7'b1100011);
assign jump_reg = (opcode == 7'b1100111);

endmodule
