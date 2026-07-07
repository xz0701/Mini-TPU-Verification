module tpu_mac_cell #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,
    input  logic                          clear_i,
    input  logic                          enable_i,
    input  logic signed [DATA_WIDTH-1:0]  a_i,
    input  logic signed [DATA_WIDTH-1:0]  b_i,
    output logic signed [DATA_WIDTH-1:0]  a_o,
    output logic signed [DATA_WIDTH-1:0]  b_o,
    output logic signed [ACC_WIDTH-1:0]   acc_o
);

    logic signed [(2*DATA_WIDTH)-1:0] product;

    assign product = a_i * b_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            a_o   <= '0;
            b_o   <= '0;
            acc_o <= '0;
        end else if (clear_i) begin
            a_o   <= '0;
            b_o   <= '0;
            acc_o <= '0;
        end else if (enable_i) begin
            a_o   <= a_i;
            b_o   <= b_i;
            acc_o <= acc_o + {{(ACC_WIDTH-(2*DATA_WIDTH)){product[(2*DATA_WIDTH)-1]}}, product};
        end
    end

endmodule
