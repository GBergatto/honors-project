module immgen (
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [31:0] inst,
   output logic [31:0] imm
);

logic [6:0] opcode;
assign opcode = inst[6:0];

always_comb begin
   case (opcode)
      7'b0010011, // I-type
      7'b0000011, // load
      7'b1100111: // JALR
         imm = {{20{inst[31]}}, inst[31:20]};

      7'b0100011: // S-type
         imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

      7'b1100011: // B-type
         imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};

      7'b1101111: // JAL
         imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};

      // TODO: support U-type

      default:
         imm = 32'b0;
   endcase
end

endmodule
