module hp_core (
    input logic clk,
    input logic rst
);

/* Program Counter */
logic [31:2] pc, next_pc; // no low 2 bits because we're only addressing 32-bit instructions

always_ff @(posedge clk or posedge rst) begin
   if (rst)
      pc <= 30'h0;
   else if (!stall)
      pc <= next_pc;
end

// TODO: implement branching
always_comb next_pc = pc + 1;

/* Instruction Memory */
logic [31:0] inst;
imem #(8) imem_i (
   .rst (rst),
   .clk (clk),
   .pc (pc),
   .inst (inst)
);

/* == IF/ID pipeline registers == */
logic [31:2] IFID_next_pc;
logic [31:0] IFID_inst;
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      IFID_next_pc <= 30'b0;
      IFID_inst <= 32'b0;
   end else if (!stall) begin
      IFID_next_pc <= next_pc;
      IFID_inst <= inst;
   end
end

/* Immediate Generator */
logic [31:0] imm;
immgen immgen_i (
   .inst (IFID_inst),
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
   opcode = IFID_inst[6:0];
   rd     = IFID_inst[11:7];
   funct3 = IFID_inst[14:12];
   rs1    = IFID_inst[19:15];
   rs2    = IFID_inst[24:20];
   funct7 = IFID_inst[31:25];
end

/* Control Logic */
logic alu_src;
control control_i (
   .opcode (opcode),
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_src (alu_src),
   .reg_write (reg_write),
   .mem_read (mem_read),
   .mem_write (mem_write),
   .mem_to_reg (mem_to_reg)
);

alu_op_t alu_op;
alu_control alu_control_i (
   .funct3 (funct3),
   .funct7 (funct7),
   .alu_op (alu_op)
);

/* Hazard Detection (during ID) */
logic stall;
assign stall = (IDEX_rd  != 0 && IDEX_ctrl.reg_write  && (rs1 == IDEX_rd  || (!alu_src && rs2 == IDEX_rd ))) ||
               (EXMEM_rd != 0 && EXMEM_ctrl.reg_write && (rs1 == EXMEM_rd || (!alu_src && rs2 == EXMEM_rd))) ||
               (MEMWB_rd != 0 && MEMWB_ctrl.reg_write && (rs1 == MEMWB_rd || (!alu_src && rs2 == MEMWB_rd)));

/* Register File */
logic reg_write, mem_to_reg, mem_read, mem_write;
logic [31:0] rs1_data, rs2_data, wb_data;
regfile regfile_i (
   .clk (clk),
   .rs1 (rs1),
   .rs2 (rs2),
   .rd (MEMWB_rd),
   .rd_data (wb_data),
   .write (MEMWB_ctrl.reg_write),
   .rs1_data (rs1_data),
   .rs2_data (rs2_data)
);

/* == ID/EX pipeline registers == */
// TODO: use this struct as output of the control module??
typedef struct packed {
   alu_op_t alu_op; // from alu_control
   logic alu_src; // the rest if from control
   logic reg_write;
   logic mem_write;
   logic mem_read;
   logic mem_to_reg;
} ctrl_bundle_t;

ctrl_bundle_t IDEX_ctrl;
logic [31:0] IDEX_rs1_data, IDEX_rs2_data, IDEX_imm;
/* verilator lint_off UNUSEDSIGNAL */
logic [31:2] IDEX_next_pc;
/* verilator lint_off UNUSEDSIGNAL */
logic [4:0] IDEX_rs1, IDEX_rs2, IDEX_rd; // TODO: hazard detection and forwarding

always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      IDEX_ctrl <= '0;
      IDEX_rs1_data <= 0;
      IDEX_rs2_data <= 0;
      IDEX_imm <= 0;
      IDEX_rs1 <= 0;
      IDEX_rs2 <= 0;
   end else if (stall) begin
      // inject bubble in the EX stage, i.e. do nothing for one cycle
      IDEX_ctrl <= '0;
      IDEX_rd <= '0;
   end else begin
      IDEX_ctrl.alu_op <= alu_op;
      IDEX_ctrl.alu_src <= alu_src;
      IDEX_ctrl.reg_write <= reg_write;
      IDEX_ctrl.mem_write <= mem_write;
      IDEX_ctrl.mem_read <= mem_read;
      IDEX_ctrl.mem_to_reg <= mem_to_reg;

      IDEX_rs1_data <= rs1_data;
      IDEX_rs2_data <= rs2_data;
      IDEX_imm <= imm;
      IDEX_rs1 <= rs1;
      IDEX_rs2 <= rs2;
      IDEX_rd <= rd;
      IDEX_next_pc <= IFID_next_pc;
   end
end

/* ALU */
logic [31:0] y, alu_out;
assign y = (IDEX_ctrl.alu_src) ? IDEX_imm : IDEX_rs2_data;

alu alu_i (
   .op1 (IDEX_rs1_data),
   .op2 (y),
   .alu_op (IDEX_ctrl.alu_op),
   .out (alu_out)
);

/* == EX/MEM pipeline registers == */
typedef struct packed {
   logic mem_read;
   logic mem_write;
   logic reg_write;
   logic mem_to_reg;
} ctrl_exmem_t;

/* verilator lint_off UNUSEDSIGNAL */
ctrl_exmem_t EXMEM_ctrl;
logic [31:0] EXMEM_alu_out, EXMEM_rs2_data;
logic [4:0]  EXMEM_rd;

always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      EXMEM_ctrl <= '0;
      EXMEM_alu_out <= 0; EXMEM_rs2_data <= 0; EXMEM_rd <= 0;
   end else begin
      EXMEM_ctrl.reg_write <= IDEX_ctrl.reg_write;
      EXMEM_ctrl.mem_read  <= IDEX_ctrl.mem_read;
      EXMEM_ctrl.mem_write <= IDEX_ctrl.mem_write;
      EXMEM_ctrl.mem_to_reg <= IDEX_ctrl.mem_to_reg;

      EXMEM_alu_out <= alu_out;
      EXMEM_rs2_data <= IDEX_rs2_data;
      EXMEM_rd <= IDEX_rd;
   end
end

/* Data Memory */
logic [31:0] mem_out;
dmem #(8) dmem_i (
   .clk (clk),
   .re (EXMEM_ctrl.mem_read),
   .we (EXMEM_ctrl.mem_write),
   .addr (EXMEM_alu_out),
   .wdata (EXMEM_rs2_data),
   .rdata (mem_out)
);

/* == MEM/WB pipeline registers == */
typedef struct packed {
    logic reg_write;
    logic mem_to_reg;
} ctrl_memwb_t;

/* verilator lint_off UNUSEDSIGNAL */
ctrl_memwb_t MEMWB_ctrl;
logic [31:0] MEMWB_mem_out, MEMWB_alu_out;
logic [4:0]  MEMWB_rd;
always_ff @(posedge clk or posedge rst) begin
   if (rst) begin
      MEMWB_alu_out <= 0;
      MEMWB_mem_out <= 0;
      MEMWB_rd <= 0;
      MEMWB_ctrl.mem_to_reg <= 0;
      MEMWB_ctrl.reg_write <= 0;
   end else begin
      MEMWB_alu_out <= EXMEM_alu_out;
      MEMWB_mem_out <= mem_out;
      MEMWB_rd <= EXMEM_rd;
      MEMWB_ctrl.mem_to_reg <= EXMEM_ctrl.mem_to_reg;
      MEMWB_ctrl.reg_write <= EXMEM_ctrl.reg_write;
   end
end

/* Write Back */
assign wb_data = (MEMWB_ctrl.mem_to_reg) ? MEMWB_mem_out : MEMWB_alu_out;

endmodule

