`timescale 1ns/1ps

module tb_systolic_smoke;

    localparam int ARRAY_SIZE = 4;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH  = 32;

    logic clk;
    logic rst_n;
    logic start;
    logic busy;
    logic done;

    logic signed [DATA_WIDTH-1:0] a_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [DATA_WIDTH-1:0] b_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0]  c_matrix [ARRAY_SIZE][ARRAY_SIZE];
    int signed expected [ARRAY_SIZE][ARRAY_SIZE];
    int error_count;

    mini_tpu_core #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) dut (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .start_i    (start),
        .a_matrix_i (a_matrix),
        .b_matrix_i (b_matrix),
        .busy_o     (busy),
        .done_o     (done),
        .c_matrix_o (c_matrix)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        error_count = 0;

        clear_matrices();

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        load_mixed_signed_case();
        run_case("mixed_signed");

        load_identity_case();
        run_case("identity");

        load_zero_case();
        run_case("zero");

        load_int8_edge_case();
        run_case("int8_edge");

        run_back_to_back_case();
        run_reset_during_compute_case();

        if (error_count == 0) begin
            $display("[MINI_TPU_SMOKE] PASS: all directed 4x4 int8 systolic cases matched expected results.");
        end else begin
            $fatal(1, "[MINI_TPU_SMOKE] FAIL: %0d mismatches detected.", error_count);
        end

        $finish;
    end

    task automatic clear_matrices();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = '0;
                b_matrix[row][col] = '0;
                expected[row][col] = 0;
            end
        end
    endtask

    task automatic load_mixed_signed_case();
        a_matrix[0][0] =  1; a_matrix[0][1] =  2; a_matrix[0][2] =  3; a_matrix[0][3] =  4;
        a_matrix[1][0] = -1; a_matrix[1][1] =  0; a_matrix[1][2] =  2; a_matrix[1][3] =  1;
        a_matrix[2][0] =  3; a_matrix[2][1] = -2; a_matrix[2][2] =  1; a_matrix[2][3] =  0;
        a_matrix[3][0] =  2; a_matrix[3][1] =  1; a_matrix[3][2] = -3; a_matrix[3][3] =  2;

        b_matrix[0][0] =  1; b_matrix[0][1] =  0; b_matrix[0][2] = -1; b_matrix[0][3] =  2;
        b_matrix[1][0] =  2; b_matrix[1][1] =  1; b_matrix[1][2] =  0; b_matrix[1][3] = -2;
        b_matrix[2][0] = -1; b_matrix[2][1] =  3; b_matrix[2][2] =  2; b_matrix[2][3] =  1;
        b_matrix[3][0] =  0; b_matrix[3][1] = -2; b_matrix[3][2] =  1; b_matrix[3][3] =  1;
    endtask

    task automatic load_identity_case();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = (row == col) ? 8'sd1 : 8'sd0;
                b_matrix[row][col] = (row * ARRAY_SIZE) + col + 1;
            end
        end
    endtask

    task automatic load_zero_case();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = '0;
                b_matrix[row][col] = ((row + col) % 2 == 0) ? 8'sd7 : -8'sd5;
            end
        end
    endtask

    task automatic load_int8_edge_case();
        a_matrix[0][0] =  8'sd127; a_matrix[0][1] =  8'sh80;  a_matrix[0][2] =   8'sd1; a_matrix[0][3] =  -8'sd1;
        a_matrix[1][0] = -8'sd64;  a_matrix[1][1] =   8'sd63; a_matrix[1][2] =  8'sd32; a_matrix[1][3] = -8'sd32;
        a_matrix[2][0] =   8'sd0;  a_matrix[2][1] =  8'sd16; a_matrix[2][2] = -8'sd16; a_matrix[2][3] =  8'sd8;
        a_matrix[3][0] =  -8'sd8;  a_matrix[3][1] =   8'sd4; a_matrix[3][2] =  -8'sd4; a_matrix[3][3] =  8'sd2;

        b_matrix[0][0] =  -8'sd1; b_matrix[0][1] =   8'sd2; b_matrix[0][2] =  -8'sd3; b_matrix[0][3] =   8'sd4;
        b_matrix[1][0] =   8'sd5; b_matrix[1][1] =  -8'sd6; b_matrix[1][2] =   8'sd7; b_matrix[1][3] =  -8'sd8;
        b_matrix[2][0] =   8'sd9; b_matrix[2][1] = -8'sd10; b_matrix[2][2] =  8'sd11; b_matrix[2][3] = -8'sd12;
        b_matrix[3][0] = -8'sd13; b_matrix[3][1] =  8'sd14; b_matrix[3][2] = -8'sd15; b_matrix[3][3] =  8'sd16;
    endtask

    task automatic run_case(input string case_name);
        $display("[MINI_TPU_SMOKE] Starting case: %s", case_name);
        compute_expected();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait (done === 1'b1);
        @(posedge clk);
        check_result(case_name);
        repeat (2) @(posedge clk);
    endtask

    task automatic run_back_to_back_case();
        $display("[MINI_TPU_SMOKE] Starting case: back_to_back_identity_to_mixed");

        load_identity_case();
        compute_expected();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait (done === 1'b1);
        @(posedge clk);
        check_result("back_to_back_identity");

        load_mixed_signed_case();
        compute_expected();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait (done === 1'b1);
        @(posedge clk);
        check_result("back_to_back_mixed");
        repeat (2) @(posedge clk);
    endtask

    task automatic run_reset_during_compute_case();
        $display("[MINI_TPU_SMOKE] Starting case: reset_during_compute");

        load_int8_edge_case();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        if (busy !== 1'b0 || done !== 1'b0) begin
            $display("[MINI_TPU_SMOKE] MISMATCH reset_during_compute control: busy=%0b done=%0b",
                     busy, done);
            error_count++;
        end

        check_outputs_zero("reset_during_compute");

        load_mixed_signed_case();
        run_case("post_reset_mixed");
    endtask

    task automatic compute_expected();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expected[row][col] = 0;
                for (int k = 0; k < ARRAY_SIZE; k++) begin
                    expected[row][col] += a_matrix[row][k] * b_matrix[k][col];
                end
            end
        end
    endtask

    task automatic check_result(input string case_name);
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                if (c_matrix[row][col] !== expected[row][col]) begin
                    $display("[MINI_TPU_SMOKE] MISMATCH %s C[%0d][%0d]: actual=%0d expected=%0d",
                             case_name, row, col, c_matrix[row][col], expected[row][col]);
                    error_count++;
                end else begin
                    $display("[MINI_TPU_SMOKE] MATCH %s C[%0d][%0d] = %0d",
                             case_name, row, col, c_matrix[row][col]);
                end
            end
        end
    endtask

    task automatic check_outputs_zero(input string case_name);
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                if (c_matrix[row][col] !== '0) begin
                    $display("[MINI_TPU_SMOKE] MISMATCH %s C[%0d][%0d]: actual=%0d expected=0",
                             case_name, row, col, c_matrix[row][col]);
                    error_count++;
                end else begin
                    $display("[MINI_TPU_SMOKE] MATCH %s C[%0d][%0d] = 0",
                             case_name, row, col);
                end
            end
        end
    endtask

endmodule
