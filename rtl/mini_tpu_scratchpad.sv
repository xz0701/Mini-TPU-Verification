module mini_tpu_scratchpad #(
    parameter int ARRAY_SIZE = 4,
    parameter int MAT_WIDTH  = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int IDX_WIDTH  = ((ARRAY_SIZE * ARRAY_SIZE) <= 1) ? 1 : $clog2(ARRAY_SIZE * ARRAY_SIZE)
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic                         a_we_i,
    input  logic                         b_we_i,
    input  logic [IDX_WIDTH-1:0]         wr_idx_i,
    input  logic signed [MAT_WIDTH-1:0]  wr_data_i,

    input  logic                         c_commit_i,
    input  logic signed [ACC_WIDTH-1:0]  c_commit_matrix_i [ARRAY_SIZE][ARRAY_SIZE],

    output logic signed [MAT_WIDTH-1:0]  a_matrix_o [ARRAY_SIZE][ARRAY_SIZE],
    output logic signed [MAT_WIDTH-1:0]  b_matrix_o [ARRAY_SIZE][ARRAY_SIZE],
    output logic signed [ACC_WIDTH-1:0]  c_matrix_o [ARRAY_SIZE][ARRAY_SIZE]
);

    logic signed [MAT_WIDTH-1:0] a_bank_q [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] b_bank_q [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0] c_bank_q [ARRAY_SIZE][ARRAY_SIZE];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++) begin
                    a_bank_q[row][col] <= '0;
                    b_bank_q[row][col] <= '0;
                    c_bank_q[row][col] <= '0;
                end
            end
        end else begin
            if (a_we_i) begin
                a_bank_q[wr_idx_i / ARRAY_SIZE][wr_idx_i % ARRAY_SIZE] <= wr_data_i;
            end

            if (b_we_i) begin
                b_bank_q[wr_idx_i / ARRAY_SIZE][wr_idx_i % ARRAY_SIZE] <= wr_data_i;
            end

            if (c_commit_i) begin
                for (int row = 0; row < ARRAY_SIZE; row++) begin
                    for (int col = 0; col < ARRAY_SIZE; col++) begin
                        c_bank_q[row][col] <= c_commit_matrix_i[row][col];
                    end
                end
            end
        end
    end

    always_comb begin
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix_o[row][col] = a_bank_q[row][col];
                b_matrix_o[row][col] = b_bank_q[row][col];
                c_matrix_o[row][col] = c_bank_q[row][col];
            end
        end
    end

endmodule
