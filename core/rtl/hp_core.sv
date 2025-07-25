// Simple hp-core test module
module hp_core (
    input  logic clk,
    input  logic reset,
    output logic [7:0] counter
);

    logic [7:0] count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            count <= 0;
        else
            count <= count + 1;
    end

    assign counter = count;

endmodule

