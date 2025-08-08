module control (
   input logic [6:0] opcode,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [2:0] funct3,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [6:0] funct7,
   output logic alu_src,
   output logic reg_write
);

always_comb begin
   alu_src = (opcode == 7'b0110011) ? 0 : 1;
end

always_comb begin
   case (opcode)
      7'b1100011, // branch
      7'b0100011: // store
         reg_write = 1'b0;
      default:
         reg_write = 1'b1;
   endcase
end

endmodule
