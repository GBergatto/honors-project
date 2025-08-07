module imem #(
   parameter int unsigned ADDRESS_WIDTH = 8
)(
   input logic clk,
   input logic [ADDRESS_WIDTH-1:0] addr,
   output logic [31:0] inst
);

logic [31:0] rom [1<<ADDRESS_WIDTH];

initial begin
   // load program
   $readmemh("tb/imem_init.hex", rom);
end

// synchronous read
always_ff @(posedge clk) begin
   inst <= rom[addr];
end

endmodule
