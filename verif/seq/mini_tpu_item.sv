`ifndef MINI_TPU_ITEM_SV
`define MINI_TPU_ITEM_SV

class mini_tpu_item extends uvm_sequence_item;

    `uvm_object_utils(mini_tpu_item)

    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;

    rand bit signed [7:0]  a_matrix [ARRAY_SIZE][ARRAY_SIZE];
    rand bit signed [7:0]  b_matrix [ARRAY_SIZE][ARRAY_SIZE];
    bit signed [31:0]      c_matrix [ARRAY_SIZE][ARRAY_SIZE];
    string                 case_name;

    function new(string name = "mini_tpu_item");
        super.new(name);
    endfunction

    function void clear_matrices();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = 8'sd0;
                b_matrix[row][col] = 8'sd0;
                c_matrix[row][col] = 32'sd0;
            end
        end
    endfunction

    function void set_mixed_signed();
        case_name = "mixed_signed";
        clear_matrices();

        a_matrix[0][0] =  1; a_matrix[0][1] =  2; a_matrix[0][2] =  3; a_matrix[0][3] =  4;
        a_matrix[1][0] = -1; a_matrix[1][1] =  0; a_matrix[1][2] =  2; a_matrix[1][3] =  1;
        a_matrix[2][0] =  3; a_matrix[2][1] = -2; a_matrix[2][2] =  1; a_matrix[2][3] =  0;
        a_matrix[3][0] =  2; a_matrix[3][1] =  1; a_matrix[3][2] = -3; a_matrix[3][3] =  2;

        b_matrix[0][0] =  1; b_matrix[0][1] =  0; b_matrix[0][2] = -1; b_matrix[0][3] =  2;
        b_matrix[1][0] =  2; b_matrix[1][1] =  1; b_matrix[1][2] =  0; b_matrix[1][3] = -2;
        b_matrix[2][0] = -1; b_matrix[2][1] =  3; b_matrix[2][2] =  2; b_matrix[2][3] =  1;
        b_matrix[3][0] =  0; b_matrix[3][1] = -2; b_matrix[3][2] =  1; b_matrix[3][3] =  1;
    endfunction

    function void set_identity();
        case_name = "identity";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = (row == col) ? 8'sd1 : 8'sd0;
                b_matrix[row][col] = (row * ARRAY_SIZE) + col + 1;
            end
        end
    endfunction

    function void set_all_zero();
        case_name = "all_zero";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = 8'sd0;
                b_matrix[row][col] = 8'sd0;
            end
        end
    endfunction

    function void set_int8_edge();
        case_name = "int8_edge";
        clear_matrices();

        a_matrix[0][0] =  8'sd127; a_matrix[0][1] =  8'sh80;  a_matrix[0][2] =   8'sd1; a_matrix[0][3] =  -8'sd1;
        a_matrix[1][0] = -8'sd64;  a_matrix[1][1] =   8'sd63; a_matrix[1][2] =  8'sd32; a_matrix[1][3] = -8'sd32;
        a_matrix[2][0] =   8'sd0;  a_matrix[2][1] =  8'sd16; a_matrix[2][2] = -8'sd16; a_matrix[2][3] =  8'sd8;
        a_matrix[3][0] =  -8'sd8;  a_matrix[3][1] =   8'sd4; a_matrix[3][2] =  -8'sd4; a_matrix[3][3] =  8'sd2;

        b_matrix[0][0] =  -8'sd1;  b_matrix[0][1] =   8'sd2;  b_matrix[0][2] =  -8'sd3;  b_matrix[0][3] =   8'sd4;
        b_matrix[1][0] =   8'sd5;  b_matrix[1][1] =  -8'sd6;  b_matrix[1][2] =   8'sd7;  b_matrix[1][3] =  -8'sd8;
        b_matrix[2][0] =   8'sd9;  b_matrix[2][1] = -8'sd10;  b_matrix[2][2] =  8'sd11;  b_matrix[2][3] = -8'sd12;
        b_matrix[3][0] = -8'sd13;  b_matrix[3][1] =  8'sd14;  b_matrix[3][2] = -8'sd15;  b_matrix[3][3] =  8'sd16;
    endfunction

    function void set_positive_large();
        case_name = "positive_large";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = 8'sd16 + row + col;
                b_matrix[row][col] = 8'sd32 + (row * ARRAY_SIZE) + col;
            end
        end
    endfunction

    function void set_negative_large();
        case_name = "negative_large";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = -8'sd16 - row - col;
                b_matrix[row][col] = -8'sd32 - (row * ARRAY_SIZE) - col;
            end
        end
    endfunction

    function void set_bipolar_no_zero();
        case_name = "bipolar_no_zero";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = ((row + col) % 2 == 0) ? 8'sd7 : -8'sd7;
                b_matrix[row][col] = ((row + col) % 2 == 0) ? -8'sd9 : 8'sd9;
            end
        end
    endfunction

    function void set_value_class_sweep();
        case_name = "value_class_sweep";
        clear_matrices();

        a_matrix[0][0] =   8'sd0;  a_matrix[0][1] =   8'sd1;  a_matrix[0][2] =  -8'sd1;  a_matrix[0][3] =  8'sd16;
        a_matrix[1][0] = -8'sd16;  a_matrix[1][1] =   8'sd0;  a_matrix[1][2] =   8'sd2;  a_matrix[1][3] = -8'sd2;
        a_matrix[2][0] =  8'sd32;  a_matrix[2][1] = -8'sd32;  a_matrix[2][2] =   8'sd0;  a_matrix[2][3] =  8'sd3;
        a_matrix[3][0] =  -8'sd3;  a_matrix[3][1] =  8'sd64;  a_matrix[3][2] = -8'sd64;  a_matrix[3][3] =  8'sd0;

        b_matrix[0][0] =   8'sd0;  b_matrix[0][1] =  -8'sd1;  b_matrix[0][2] =  8'sd16;  b_matrix[0][3] = -8'sd16;
        b_matrix[1][0] =   8'sd1;  b_matrix[1][1] =   8'sd0;  b_matrix[1][2] = -8'sd32;  b_matrix[1][3] =  8'sd32;
        b_matrix[2][0] =  -8'sd1;  b_matrix[2][1] =  8'sd64;  b_matrix[2][2] =   8'sd0;  b_matrix[2][3] = -8'sd64;
        b_matrix[3][0] =  8'sd16;  b_matrix[3][1] = -8'sd16;  b_matrix[3][2] =   8'sd2;  b_matrix[3][3] =  8'sd0;
    endfunction

    function void set_negative_zero_only();
        case_name = "negative_zero_only";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = ((row + col) % 2 == 0) ? -8'sd3 : 8'sd0;
                b_matrix[row][col] = ((row + col) % 2 == 0) ? -8'sd5 : 8'sd0;
            end
        end
    endfunction

    function void set_cross_sweep_low();
        case_name = "cross_sweep_low";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                int unsigned idx;
                idx = (row * ARRAY_SIZE) + col;
                a_matrix[row][col] = value_class((idx / 5) % 5);
                b_matrix[row][col] = value_class(idx % 5);
            end
        end
    endfunction

    function void set_cross_sweep_high();
        case_name = "cross_sweep_high";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                int unsigned idx;
                idx = ((row * ARRAY_SIZE) + col + 16) % 25;
                a_matrix[row][col] = value_class(idx / 5);
                b_matrix[row][col] = value_class(idx % 5);
            end
        end
    endfunction

    function void set_negative_corner_outputs();
        case_name = "negative_corner_outputs";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = (row == col) ? 8'sd1 : 8'sd0;
                b_matrix[row][col] = 8'sd2;
            end
        end

        b_matrix[0][0] = -8'sd7;
        b_matrix[0][ARRAY_SIZE-1] = -8'sd9;
        b_matrix[ARRAY_SIZE-1][0] = -8'sd11;
        b_matrix[ARRAY_SIZE-1][ARRAY_SIZE-1] = -8'sd13;
    endfunction

    function int signed expected_at(int unsigned row, int unsigned col);
        int signed a_val;
        int signed b_val;

        expected_at = 0;
        for (int k = 0; k < ARRAY_SIZE; k++) begin
            a_val = a_matrix[row][k];
            b_val = b_matrix[k][col];
            expected_at += a_val * b_val;
        end
    endfunction

    function bit signed [7:0] value_class(int unsigned idx);
        unique case (idx)
            0: value_class = -8'sd32;
            1: value_class = -8'sd3;
            2: value_class = 8'sd0;
            3: value_class = 8'sd3;
            4: value_class = 8'sd32;
            default: value_class = 8'sd0;
        endcase
    endfunction

endclass

`endif
