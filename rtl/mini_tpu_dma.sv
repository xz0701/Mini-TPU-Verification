module mini_tpu_dma #(
    parameter int ARRAY_SIZE = 4,
    parameter int MAT_WIDTH  = 8,
    parameter int IDX_WIDTH  = ((ARRAY_SIZE * ARRAY_SIZE) <= 1) ? 1 : $clog2(ARRAY_SIZE * ARRAY_SIZE)
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic                         ctrl_we_i,
    input  logic [31:0]                  ctrl_wdata_i,
    input  logic                         cfg_we_i,
    input  logic [31:0]                  cfg_wdata_i,

    input  logic                         src_a_we_i,
    input  logic                         src_b_we_i,
    input  logic [IDX_WIDTH-1:0]         src_wr_idx_i,
    input  logic signed [MAT_WIDTH-1:0]  src_wr_data_i,

    input  logic                         core_busy_i,
    input  logic                         core_bank_i,

    output logic                         busy_o,
    output logic                         done_sticky_o,
    output logic                         error_sticky_o,
    output logic                         target_bank_o,
    output logic                         copy_a_o,
    output logic                         copy_b_o,

    output logic                         dma_a_we_o,
    output logic                         dma_b_we_o,
    output logic                         dma_bank_sel_o,
    output logic [IDX_WIDTH-1:0]         dma_wr_idx_o,
    output logic signed [MAT_WIDTH-1:0]  dma_wr_data_o,

    output logic signed [MAT_WIDTH-1:0]  src_a_matrix_o [ARRAY_SIZE][ARRAY_SIZE],
    output logic signed [MAT_WIDTH-1:0]  src_b_matrix_o [ARRAY_SIZE][ARRAY_SIZE]
);

    localparam int MATRIX_ELEMENTS = ARRAY_SIZE * ARRAY_SIZE;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_COPY_A,
        ST_COPY_B
    } state_e;

    state_e state_q;
    state_e state_d;

    logic [IDX_WIDTH-1:0] idx_q;
    logic [IDX_WIDTH-1:0] idx_d;

    logic target_bank_q;
    logic copy_a_q;
    logic copy_b_q;
    logic done_sticky_q;
    logic error_sticky_q;

    logic start_req;
    logic start_allowed;
    logic last_idx;

    logic signed [MAT_WIDTH-1:0] src_a_q [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] src_b_q [ARRAY_SIZE][ARRAY_SIZE];

    assign start_req = ctrl_we_i && ctrl_wdata_i[0];
    assign start_allowed = (state_q == ST_IDLE) &&
                           (copy_a_q || copy_b_q) &&
                           !(core_busy_i && (target_bank_q == core_bank_i));
    assign last_idx = (idx_q == MATRIX_ELEMENTS-1);

    assign busy_o = (state_q != ST_IDLE);
    assign done_sticky_o = done_sticky_q;
    assign error_sticky_o = error_sticky_q;
    assign target_bank_o = target_bank_q;
    assign copy_a_o = copy_a_q;
    assign copy_b_o = copy_b_q;

    assign dma_a_we_o = (state_q == ST_COPY_A);
    assign dma_b_we_o = (state_q == ST_COPY_B);
    assign dma_bank_sel_o = target_bank_q;
    assign dma_wr_idx_o = idx_q;
    assign dma_wr_data_o = (state_q == ST_COPY_A) ?
                           src_a_q[idx_q / ARRAY_SIZE][idx_q % ARRAY_SIZE] :
                           src_b_q[idx_q / ARRAY_SIZE][idx_q % ARRAY_SIZE];

    always_comb begin
        state_d = state_q;
        idx_d = idx_q;

        unique case (state_q)
            ST_IDLE: begin
                idx_d = '0;
                if (start_req && start_allowed) begin
                    state_d = copy_a_q ? ST_COPY_A : ST_COPY_B;
                end
            end

            ST_COPY_A: begin
                if (last_idx) begin
                    idx_d = '0;
                    state_d = copy_b_q ? ST_COPY_B : ST_IDLE;
                end else begin
                    idx_d = idx_q + 1'b1;
                end
            end

            ST_COPY_B: begin
                if (last_idx) begin
                    idx_d = '0;
                    state_d = ST_IDLE;
                end else begin
                    idx_d = idx_q + 1'b1;
                end
            end

            default: begin
                state_d = ST_IDLE;
                idx_d = '0;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ST_IDLE;
            idx_q <= '0;
            target_bank_q <= 1'b0;
            copy_a_q <= 1'b1;
            copy_b_q <= 1'b1;
            done_sticky_q <= 1'b0;
            error_sticky_q <= 1'b0;

            for (int row = 0; row < ARRAY_SIZE; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++) begin
                    src_a_q[row][col] <= '0;
                    src_b_q[row][col] <= '0;
                end
            end
        end else begin
            state_q <= state_d;
            idx_q <= idx_d;

            if (cfg_we_i && !busy_o) begin
                target_bank_q <= cfg_wdata_i[0];
                copy_a_q <= cfg_wdata_i[1];
                copy_b_q <= cfg_wdata_i[2];
            end

            if (ctrl_we_i && ctrl_wdata_i[1]) begin
                done_sticky_q <= 1'b0;
            end

            if (ctrl_we_i && ctrl_wdata_i[2]) begin
                error_sticky_q <= 1'b0;
            end

            if (start_req) begin
                if (start_allowed) begin
                    done_sticky_q <= 1'b0;
                    error_sticky_q <= 1'b0;
                end else begin
                    error_sticky_q <= 1'b1;
                end
            end

            if ((state_q != ST_IDLE) && (state_d == ST_IDLE)) begin
                done_sticky_q <= 1'b1;
            end

            if (src_a_we_i && !busy_o) begin
                src_a_q[src_wr_idx_i / ARRAY_SIZE][src_wr_idx_i % ARRAY_SIZE] <= src_wr_data_i;
            end

            if (src_b_we_i && !busy_o) begin
                src_b_q[src_wr_idx_i / ARRAY_SIZE][src_wr_idx_i % ARRAY_SIZE] <= src_wr_data_i;
            end
        end
    end

    always_comb begin
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                src_a_matrix_o[row][col] = src_a_q[row][col];
                src_b_matrix_o[row][col] = src_b_q[row][col];
            end
        end
    end

endmodule
