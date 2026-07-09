module systolic_array #(
    parameter int ARRAY_SIZE = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         clear_i,
    input  logic                         enable_i,
    input  logic signed [DATA_WIDTH-1:0] row_a_i    [ARRAY_SIZE],
    input  logic signed [DATA_WIDTH-1:0] col_b_i    [ARRAY_SIZE],
    output logic signed [ACC_WIDTH-1:0]  c_matrix_o [ARRAY_SIZE][ARRAY_SIZE]
);

    logic signed [DATA_WIDTH-1:0] a_bus [ARRAY_SIZE][ARRAY_SIZE+1];
    logic signed [DATA_WIDTH-1:0] b_bus [ARRAY_SIZE+1][ARRAY_SIZE];

    genvar row;
    genvar col;

    generate
        for (row = 0; row < ARRAY_SIZE; row++) begin : gen_row_inputs
            assign a_bus[row][0] = row_a_i[row];
        end

        for (col = 0; col < ARRAY_SIZE; col++) begin : gen_col_inputs
            assign b_bus[0][col] = col_b_i[col];
        end

        for (row = 0; row < ARRAY_SIZE; row++) begin : gen_rows
            for (col = 0; col < ARRAY_SIZE; col++) begin : gen_cols
                tpu_mac_cell #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_mac_cell (
                    .clk_i    (clk_i),
                    .rst_ni   (rst_ni),
                    .clear_i  (clear_i),
                    .enable_i (enable_i),
                    .a_i      (a_bus[row][col]),
                    .b_i      (b_bus[row][col]),
                    .a_o      (a_bus[row][col+1]),
                    .b_o      (b_bus[row+1][col]),
                    .acc_o    (c_matrix_o[row][col])
                );
            end
        end
    endgenerate

endmodule
