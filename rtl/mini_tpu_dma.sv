module mini_tpu_dma #(
    parameter int ARRAY_SIZE     = 4,
    parameter int MAT_WIDTH      = 8,
    parameter int IDX_WIDTH      = ((ARRAY_SIZE * ARRAY_SIZE) <= 1) ? 1 : $clog2(ARRAY_SIZE * ARRAY_SIZE),
    parameter int EXT_ADDR_WIDTH = 32,
    parameter int EXT_DATA_WIDTH = 32
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic                         ctrl_we_i,
    input  logic [31:0]                  ctrl_wdata_i,
    input  logic                         cfg_we_i,
    input  logic [31:0]                  cfg_wdata_i,
    input  logic                         a_ext_addr_we_i,
    input  logic                         b_ext_addr_we_i,
    input  logic [EXT_ADDR_WIDTH-1:0]    ext_addr_wdata_i,

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
    output logic                         external_mode_o,
    output logic [EXT_ADDR_WIDTH-1:0]    a_ext_addr_o,
    output logic [EXT_ADDR_WIDTH-1:0]    b_ext_addr_o,

    output logic                         dma_a_we_o,
    output logic                         dma_b_we_o,
    output logic                         dma_bank_sel_o,
    output logic [IDX_WIDTH-1:0]         dma_wr_idx_o,
    output logic signed [MAT_WIDTH-1:0]  dma_wr_data_o,

    output logic signed [MAT_WIDTH-1:0]  src_a_matrix_o [ARRAY_SIZE][ARRAY_SIZE],
    output logic signed [MAT_WIDTH-1:0]  src_b_matrix_o [ARRAY_SIZE][ARRAY_SIZE],

    output logic [EXT_ADDR_WIDTH-1:0]    mem_araddr_o,
    output logic                         mem_arvalid_o,
    input  logic                         mem_arready_i,
    input  logic [EXT_DATA_WIDTH-1:0]    mem_rdata_i,
    input  logic [1:0]                   mem_rresp_i,
    input  logic                         mem_rvalid_i,
    output logic                         mem_rready_o
);

    localparam int MATRIX_ELEMENTS = ARRAY_SIZE * ARRAY_SIZE;
    localparam logic [1:0] RESP_OKAY = 2'b00;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_COPY_A_STAGE,
        ST_COPY_B_STAGE,
        ST_EXT_A_REQ,
        ST_EXT_A_WAIT,
        ST_EXT_B_REQ,
        ST_EXT_B_WAIT
    } state_e;

    state_e state_q;
    state_e state_d;

    logic [IDX_WIDTH-1:0] idx_q;
    logic [IDX_WIDTH-1:0] idx_d;

    logic target_bank_q;
    logic copy_a_q;
    logic copy_b_q;
    logic external_mode_q;
    logic [EXT_ADDR_WIDTH-1:0] a_ext_addr_q;
    logic [EXT_ADDR_WIDTH-1:0] b_ext_addr_q;
    logic done_sticky_q;
    logic error_sticky_q;

    logic start_req;
    logic start_allowed;
    logic last_idx;
    logic ext_resp_fire;
    logic ext_resp_error;
    logic ext_a_write_fire;
    logic ext_b_write_fire;

    logic signed [MAT_WIDTH-1:0] src_a_q [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] src_b_q [ARRAY_SIZE][ARRAY_SIZE];

    assign start_req = ctrl_we_i && ctrl_wdata_i[0];
    assign start_allowed = (state_q == ST_IDLE) &&
                           (copy_a_q || copy_b_q) &&
                           !(core_busy_i && (target_bank_q == core_bank_i)) &&
                           (!external_mode_q ||
                            (((!copy_a_q) || (a_ext_addr_q[1:0] == 2'b00)) &&
                             ((!copy_b_q) || (b_ext_addr_q[1:0] == 2'b00))));
    assign last_idx = (idx_q == MATRIX_ELEMENTS-1);
    assign ext_resp_fire = ((state_q == ST_EXT_A_WAIT) || (state_q == ST_EXT_B_WAIT)) &&
                           mem_rvalid_i && mem_rready_o;
    assign ext_resp_error = ext_resp_fire && (mem_rresp_i != RESP_OKAY);
    assign ext_a_write_fire = (state_q == ST_EXT_A_WAIT) && ext_resp_fire && !ext_resp_error;
    assign ext_b_write_fire = (state_q == ST_EXT_B_WAIT) && ext_resp_fire && !ext_resp_error;

    assign busy_o = (state_q != ST_IDLE);
    assign done_sticky_o = done_sticky_q;
    assign error_sticky_o = error_sticky_q;
    assign target_bank_o = target_bank_q;
    assign copy_a_o = copy_a_q;
    assign copy_b_o = copy_b_q;
    assign external_mode_o = external_mode_q;
    assign a_ext_addr_o = a_ext_addr_q;
    assign b_ext_addr_o = b_ext_addr_q;

    assign dma_a_we_o = (state_q == ST_COPY_A_STAGE) || ext_a_write_fire;
    assign dma_b_we_o = (state_q == ST_COPY_B_STAGE) || ext_b_write_fire;
    assign dma_bank_sel_o = target_bank_q;
    assign dma_wr_idx_o = idx_q;
    assign dma_wr_data_o = ((state_q == ST_EXT_A_WAIT) || (state_q == ST_EXT_B_WAIT)) ?
                           mem_rdata_i[MAT_WIDTH-1:0] :
                           ((state_q == ST_COPY_A_STAGE) ?
                            src_a_q[idx_q / ARRAY_SIZE][idx_q % ARRAY_SIZE] :
                            src_b_q[idx_q / ARRAY_SIZE][idx_q % ARRAY_SIZE]);

    assign mem_arvalid_o = (state_q == ST_EXT_A_REQ) || (state_q == ST_EXT_B_REQ);
    assign mem_araddr_o = ((state_q == ST_EXT_A_REQ) || (state_q == ST_EXT_A_WAIT)) ?
                          (a_ext_addr_q + ext_byte_offset(idx_q)) :
                          (b_ext_addr_q + ext_byte_offset(idx_q));
    assign mem_rready_o = (state_q == ST_EXT_A_WAIT) || (state_q == ST_EXT_B_WAIT);

    function automatic logic [EXT_ADDR_WIDTH-1:0] ext_byte_offset(input logic [IDX_WIDTH-1:0] idx);
        ext_byte_offset = '0;
        ext_byte_offset[IDX_WIDTH+1:2] = idx;
    endfunction

    always_comb begin
        state_d = state_q;
        idx_d = idx_q;

        unique case (state_q)
            ST_IDLE: begin
                idx_d = '0;
                if (start_req && start_allowed) begin
                    if (external_mode_q) begin
                        state_d = copy_a_q ? ST_EXT_A_REQ : ST_EXT_B_REQ;
                    end else begin
                        state_d = copy_a_q ? ST_COPY_A_STAGE : ST_COPY_B_STAGE;
                    end
                end
            end

            ST_COPY_A_STAGE: begin
                if (last_idx) begin
                    idx_d = '0;
                    state_d = copy_b_q ? ST_COPY_B_STAGE : ST_IDLE;
                end else begin
                    idx_d = idx_q + 1'b1;
                end
            end

            ST_COPY_B_STAGE: begin
                if (last_idx) begin
                    idx_d = '0;
                    state_d = ST_IDLE;
                end else begin
                    idx_d = idx_q + 1'b1;
                end
            end

            ST_EXT_A_REQ: begin
                if (mem_arready_i) begin
                    state_d = ST_EXT_A_WAIT;
                end
            end

            ST_EXT_A_WAIT: begin
                if (ext_resp_error) begin
                    idx_d = '0;
                    state_d = ST_IDLE;
                end else if (ext_resp_fire) begin
                    if (last_idx) begin
                        idx_d = '0;
                        state_d = copy_b_q ? ST_EXT_B_REQ : ST_IDLE;
                    end else begin
                        idx_d = idx_q + 1'b1;
                        state_d = ST_EXT_A_REQ;
                    end
                end
            end

            ST_EXT_B_REQ: begin
                if (mem_arready_i) begin
                    state_d = ST_EXT_B_WAIT;
                end
            end

            ST_EXT_B_WAIT: begin
                if (ext_resp_error) begin
                    idx_d = '0;
                    state_d = ST_IDLE;
                end else if (ext_resp_fire) begin
                    if (last_idx) begin
                        idx_d = '0;
                        state_d = ST_IDLE;
                    end else begin
                        idx_d = idx_q + 1'b1;
                        state_d = ST_EXT_B_REQ;
                    end
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
            external_mode_q <= 1'b0;
            a_ext_addr_q <= '0;
            b_ext_addr_q <= '0;
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
                external_mode_q <= cfg_wdata_i[3];
            end

            if (a_ext_addr_we_i && !busy_o) begin
                a_ext_addr_q <= ext_addr_wdata_i;
            end

            if (b_ext_addr_we_i && !busy_o) begin
                b_ext_addr_q <= ext_addr_wdata_i;
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

            if (ext_resp_error) begin
                error_sticky_q <= 1'b1;
            end

            if ((state_q != ST_IDLE) && (state_d == ST_IDLE) && !ext_resp_error) begin
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
