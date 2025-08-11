module dmem #(
   parameter int unsigned AW = 8 // address width
)(
   input logic clk,
   input logic re, // read enable
   input logic we, // write enable
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [31:0] addr,
   input logic [31:0] wdata,
   output logic [31:0] rdata
);

logic [31:0] ram [1<<AW];

// synchronous read + write
always_ff @(posedge clk) begin
   //if (re) begin
   //   rdata <= ram[addr[AW-1:0]];
   //end
   if (we) begin
      ram[addr[AW-1:0]] <= wdata;
   end
end

// TODO: make read synchronous again
always_comb begin
   if (re) begin
      rdata = ram[addr[AW-1:0]];
   end else begin
      rdata = 32'h0;
   end
end

endmodule
