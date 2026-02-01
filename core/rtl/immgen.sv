module immgen (
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [31:0] inst,
   output logic [31:0] imm
);

logic [6:0] opcode;
assign opcode = inst[6:0];

always_comb begin
   case (opcode)
      7'b0010011, 7'b0000011: // I-type
         imm = {{20{inst[31]}}, inst[31:20]};

      7'b0100011: // S-type
         imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

      // TODO: support missing instruction types

      default:
         imm = 32'h0;
   endcase
end

endmodule
