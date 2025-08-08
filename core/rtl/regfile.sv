module regfile (
   input logic clk,
   input logic [4:0] rs1,
   input logic [4:0] rs2,
   input logic [4:0] rd,
   input logic [31:0] rd_data,
   input logic write,
   output logic [31:0] rs1_data,
   output logic [31:0] rs2_data
);

logic [31:0] regs[32];

`ifdef verilator
    function [31:0] get_reg;
        input [4:0] index; // or input [4:0] index;
        // verilator public
        get_reg = regs[index];
    endfunction
`endif

// asynchronous read (x0 is hardwired to zero)
assign rs1_data = (rs1 == 5'h0) ? 32'h0 : regs[rs1];
assign rs2_data = (rs2 == 5'h0) ? 32'h0 : regs[rs2];

// synchronous write
always_ff @(posedge clk) begin
   if (write && rd != 5'h0) begin
      regs[rd] <= rd_data;
   end
end

endmodule
