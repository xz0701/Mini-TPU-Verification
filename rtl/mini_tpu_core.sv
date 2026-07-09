module mini_tpu_core #(
    parameter int ARRAY_SIZE = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         start_i,
    input  logic signed [DATA_WIDTH-1:0] a_matrix_i [ARRAY_SIZE][ARRAY_SIZE],
    input  logic signed [DATA_WIDTH-1:0] b_matrix_i [ARRAY_SIZE][ARRAY_SIZE],
    output logic                         busy_o,
    output logic                         done_o,
    output logic signed [ACC_WIDTH-1:0]  c_matrix_o [ARRAY_SIZE][ARRAY_SIZE]
);

    localparam int TOTAL_CYCLES = (3 * ARRAY_SIZE) - 2;
    localparam int CYCLE_W      = (TOTAL_CYCLES <= 1) ? 1 : $clog2(TOTAL_CYCLES);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_CLEAR,
        ST_RUN,
        ST_DONE
    } state_e;

    state_e state_q;
    state_e state_d;

    logic [CYCLE_W-1:0] cycle_q;
    logic [CYCLE_W-1:0] cycle_d;

    logic clear_array;
    logic enable_array;

    logic signed [DATA_WIDTH-1:0] row_a_feed [ARRAY_SIZE];
    logic signed [DATA_WIDTH-1:0] col_b_feed [ARRAY_SIZE];

    always_comb begin
        state_d = state_q;
        cycle_d = cycle_q;

        unique case (state_q)
            ST_IDLE: begin
                cycle_d = '0;
                if (start_i) begin
                    state_d = ST_CLEAR;
                end
            end

            ST_CLEAR: begin
                cycle_d = '0;
                state_d = ST_RUN;
            end

            ST_RUN: begin
                if (cycle_q == TOTAL_CYCLES-1) begin
                    cycle_d = '0;
                    state_d = ST_DONE;
                end else begin
                    cycle_d = cycle_q + 1'b1;
                end
            end

            ST_DONE: begin
                cycle_d = '0;
                if (start_i) begin
                    state_d = ST_CLEAR;
                end else begin
                    state_d = ST_IDLE;
                end
            end

            default: begin
                state_d = ST_IDLE;
                cycle_d = '0;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ST_IDLE;
            cycle_q <= '0;
        end else begin
            state_q <= state_d;
            cycle_q <= cycle_d;
        end
    end

    assign busy_o      = (state_q == ST_CLEAR) || (state_q == ST_RUN);
    assign done_o      = (state_q == ST_DONE);
    assign clear_array = (state_q == ST_CLEAR);
    assign enable_array = (state_q == ST_RUN);

    always_comb begin
        int feed_idx;

        for (int i = 0; i < ARRAY_SIZE; i++) begin
            row_a_feed[i] = '0;
            col_b_feed[i] = '0;
        end

        if (state_q == ST_RUN) begin
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                feed_idx = int'(cycle_q) - row;
                if ((feed_idx >= 0) && (feed_idx < ARRAY_SIZE)) begin
                    row_a_feed[row] = a_matrix_i[row][feed_idx];
                end
            end

            for (int col = 0; col < ARRAY_SIZE; col++) begin
                feed_idx = int'(cycle_q) - col;
                if ((feed_idx >= 0) && (feed_idx < ARRAY_SIZE)) begin
                    col_b_feed[col] = b_matrix_i[feed_idx][col];
                end
            end
        end
    end

    systolic_array #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_systolic_array (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .clear_i    (clear_array),
        .enable_i   (enable_array),
        .row_a_i    (row_a_feed),
        .col_b_i    (col_b_feed),
        .c_matrix_o (c_matrix_o)
    );

endmodule
