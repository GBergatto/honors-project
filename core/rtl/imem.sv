module imem #(
   parameter int unsigned AW = 8 // address width
)(
   input logic clk,
   /* verilator lint_off UNUSEDSIGNAL */
   input logic [29:0] pc,
   output logic [31:0] inst
);

logic [31:0] rom [1<<AW];

initial begin
   // load program
   $readmemh("tb/firmware.hex", rom);
end

// synchronous read
always_ff @(posedge clk) begin
    // use only the low AW bits of PC as the ROM index
   inst <= rom[pc[AW-1:0]];
end

endmodule
