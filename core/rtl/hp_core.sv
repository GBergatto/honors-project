/* verilator lint_off IMPORTSTAR */
import core_types_pkg::*;

module hp_core (
    input logic clk,
    input logic rst
);

/* Control Signals Structs */
typedef struct packed {
   alu_op_t alu_op;
   logic alu_src;
   logic reg_write;
   logic mem_write;
   logic mem_read;
   logic mem_to_reg;
} ctrl_E_t;

typedef struct packed {
   logic mem_read;
   logic mem_write;
   logic reg_write;
   logic mem_to_reg;
} ctrl_M_t;

typedef struct packed {
    logic reg_write;
    logic mem_to_reg;
} ctrl_W_t;


ctrl_E_t ctrl_E;
ctrl_M_t ctrl_M;
ctrl_W_t ctrl_W;

// ===================================================================================
// Fetch Stage
// ===================================================================================
logic stall;
logic [31:2] pc, pc_plus4; // no low 2 bits because we're only addressing 32-bit instructions

/* Program Counter */
always_ff @(posedge clk or posedge rst) begin
   if (rst)
      pc <= 30'h0;
   else if (!stall)
      pc <= pc_plus4;
end

// TODO: implement branching
always_comb pc_plus4 = pc + 1;

/* Instruction Memory */
logic [31:0] inst;
imem #(8) imem_i (
   .clk (clk),
   .rst (rst),
   .enable (!stall),
   .pc (pc),
   .inst (inst)
);

// ===================================================================================
// Decode Stage
// ===================================================================================
logic [31:2] pc_D;
logic [31:0] inst_D;

/* IF/ID pipeline registers */
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      pc_D <= 30'b0;
      inst_D <= 32'b0;
   end else if (!stall) begin
      pc_D <= pc_plus4;
      inst_D <= inst;
   end
end

/* Immediate Generator */
logic [31:0] imm_D;
immgen immgen_i (
   .inst (inst_D),
   .imm (imm_D)
);

/* Decoder */
logic [6:0] opcode;
logic [4:0] rd_D;
logic [2:0] funct3;
logic [4:0] rs1_D;
logic [4:0] rs2_D;
logic [6:0] funct7;

always_comb begin
   opcode = inst_D[6:0];
   rd_D   = inst_D[11:7];
   funct3 = inst_D[14:12];
   rs1_D  = inst_D[19:15];
   rs2_D  = inst_D[24:20];
   funct7 = inst_D[31:25];
end

/* Control Logic */
logic alu_src_D, reg_write_D, mem_to_reg_D, mem_read_D, mem_write_D;
control control_i (
   .opcode (opcode),
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_src (alu_src_D),
   .reg_write (reg_write_D),
   .mem_read (mem_read_D),
   .mem_write (mem_write_D),
   .mem_to_reg (mem_to_reg_D)
);

/* ALU Control Logic */
alu_op_t alu_op;
alu_control alu_control_i (
   .opcode (opcode),
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_op (alu_op)
);

logic [4:0] rd_E, rd_M, rd_W, rs1_E, rs2_E;

/* Hazard Detection */
logic [1:0] forward_a_E, forward_b_E;
// Stall only if the instruction in D reads the output of a load in E
assign stall = ctrl_E.mem_read && (rd_E == rs1_D || rd_E == rs2_D);

// Forwarding for source op1
always_comb begin
   if (rd_M != 0 && rs1_E == rd_M && ctrl_M.reg_write) begin
      forward_a_E = 2'b10; // Forward from MEM
   end else if (rd_W != 0 && rs1_E == rd_W && ctrl_W.reg_write) begin
      forward_a_E = 2'b01; // Forward from WB
   end else begin
      forward_a_E = 2'b00; // No Forwarding
   end
end

// Forwarding for source B
always_comb begin
   if (rd_M != 0 && rs2_E == rd_M && ctrl_M.reg_write) begin
      forward_b_E = 2'b10; // Forward from MEM
   end else if (rd_W != 0 && rs2_E == rd_W && ctrl_W.reg_write) begin
      forward_b_E = 2'b01; // Forward from WB
   end else begin
      forward_b_E = 2'b00; // No Forwarding
   end
end

/* Register File */
logic [31:0] rs1_data_D, rs2_data_D, result_W;
regfile regfile_i (
   .clk (clk),
   .rs1 (rs1_D),
   .rs2 (rs2_D),
   .rd (rd_W),
   .rd_data (result_W),
   .write (ctrl_W.reg_write),
   .rs1_data (rs1_data_D),
   .rs2_data (rs2_data_D)
);

// ===================================================================================
// Execute Stage
// ===================================================================================
logic [31:0] rs1_data_E, rs2_data_E, imm_E;
/* verilator lint_off UNUSEDSIGNAL */
logic [31:2] pc_E;

/* ID/EX pipeline registers */
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      ctrl_E <= '0;
      rs1_data_E <= 0;
      rs2_data_E <= 0;
      imm_E <= 0;
      rs1_E <= 0;
      rs2_E <= 0;
   end else if (stall) begin
      // inject bubble in the EX stage, i.e. do nothing for one cycle
      ctrl_E <= '0;
      rd_E <= '0;
   end else begin
      ctrl_E.alu_op <= alu_op;
      ctrl_E.alu_src <= alu_src_D;
      ctrl_E.reg_write <= reg_write_D;
      ctrl_E.mem_write <= mem_write_D;
      ctrl_E.mem_read <= mem_read_D;
      ctrl_E.mem_to_reg <= mem_to_reg_D;

      rs1_data_E <= rs1_data_D;
      rs2_data_E <= rs2_data_D;
      imm_E <= imm_D;
      rs1_E <= rs1_D;
      rs2_E <= rs2_D;
      rd_E <= rd_D;
      pc_E <= pc_D;
   end
end

logic [31:0] write_data_E, op1, op2, alu_out_M;

/* Forwarding Multiplexers */
always_comb begin
    case (forward_a_E)
        2'b00: op1 = rs1_data_E; // No forwarding
        2'b01: op1 = result_W;   // Forwarded from Writeback stage
        2'b10: op1 = alu_out_M;  // Forwarded from Memory stage
        default: op1 = rs1_data_E;
    endcase

    case (forward_b_E)
        2'b00: write_data_E = rs2_data_E; // No forwarding
        2'b01: write_data_E = result_W;   // Forwarded from Writeback stage
        2'b10: write_data_E = alu_out_M;  // Forwarded from Memory stage
        default: write_data_E = rs2_data_E;
    endcase
end

/* ALU */
logic [31:0] alu_out_D;
assign op2 = (ctrl_E.alu_src) ? imm_E : write_data_E;

alu alu_i (
   .op1 (signed'(op1)),
   .op2 (signed'(op2)),
   .alu_op (ctrl_E.alu_op),
   .out (alu_out_D)
);

// ===================================================================================
// Memory Stage
// ===================================================================================
logic [31:0] write_data_M;

/* EX/MEM pipeline registers */
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      ctrl_M <= '0;
      alu_out_M <= 0; write_data_M <= 0; rd_M <= 0;
   end else begin
      ctrl_M.reg_write <= ctrl_E.reg_write;
      ctrl_M.mem_read  <= ctrl_E.mem_read;
      ctrl_M.mem_write <= ctrl_E.mem_write;
      ctrl_M.mem_to_reg <= ctrl_E.mem_to_reg;

      alu_out_M <= alu_out_D;
      write_data_M <= write_data_E;
      rd_M <= rd_E;
   end
end

/* Data Memory */
logic [31:0] mem_out;
dmem #(8) dmem_i (
   .clk (clk),
   .re (ctrl_M.mem_read),
   .we (ctrl_M.mem_write),
   .addr (alu_out_M),
   .wdata (write_data_M),
   .rdata (mem_out)
);

// ===================================================================================
// Writeback Stage
// ===================================================================================
logic [31:0] alu_out_W;

/* MEM/WB pipeline registers */
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      alu_out_W <= 0;
      rd_W <= 0;
      ctrl_W.mem_to_reg <= 0;
      ctrl_W.reg_write <= 0;
   end else begin
      alu_out_W <= alu_out_M;
      rd_W <= rd_M;
      ctrl_W.mem_to_reg <= ctrl_M.mem_to_reg;
      ctrl_W.reg_write <= ctrl_M.reg_write;
   end
end

assign result_W = (ctrl_W.mem_to_reg) ? mem_out : alu_out_W;

endmodule

