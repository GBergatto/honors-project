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
   output logic mem_to_reg
);

assign alu_src = (opcode != 7'b0110011);

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
assign mem_to_reg = (opcode == 7'b0000011);

endmodule
