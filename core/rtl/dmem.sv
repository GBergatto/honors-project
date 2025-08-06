module dmem #(
   parameter int unsigned ADDRESS_WIDTH = 8
)(
   input logic clk,
   input logic we, // write enable
   input logic [ADDRESS_WIDTH-1:0] addr,
   input logic [32:0] wdata,
   output logic [32:0] rdata
);

logic [32:0] ram [1<<ADDRESS_WIDTH];

// synchronous read + write
always_ff @(posedge clk) begin
   if (we) begin
      ram[addr] <= wdata;
   end
   rdata <= ram[addr];
end

endmodule
