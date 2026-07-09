`ifndef MINI_TPU_8X8_STRESS_TEST_SV
`define MINI_TPU_8X8_STRESS_TEST_SV

class mini_tpu_8x8_stress_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_8x8_stress_test)

    function new(string name = "mini_tpu_8x8_stress_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item item;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_8X8_STRESS", $sformatf("Starting %0dx%0d scale stress test", ARRAY_SIZE, ARRAY_SIZE), UVM_LOW)

        item = mini_tpu_item::type_id::create("item");

        fill_dense_signed(item);
        run_checked_item(item);

        fill_sparse_diagonal(item);
        run_checked_item(item);

        fill_checkerboard(item);
        run_checked_item(item);

        `uvm_info("MINI_TPU_8X8_STRESS", "Scale stress test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

    task automatic run_checked_item(mini_tpu_item item);
        load_item(item);
        start_core();
        poll_done();
        check_result(item);
        clear_done_sticky();
    endtask

    function void fill_dense_signed(mini_tpu_item item);
        int signed a_val;
        int signed b_val;

        item.clear_matrices();
        item.case_name = "dense_signed_scale";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_val = int'(((row * 5) + (col * 3)) % 17) - 8;
                b_val = int'(((row * 7) + (col * 2) + 3) % 19) - 9;
                item.a_matrix[row][col] = a_val[7:0];
                item.b_matrix[row][col] = b_val[7:0];
            end
        end
    endfunction

    function void fill_sparse_diagonal(mini_tpu_item item);
        int signed b_val;

        item.clear_matrices();
        item.case_name = "sparse_diagonal_scale";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                if (row == col) begin
                    item.a_matrix[row][col] = (row % 2 == 0) ? 8'sd1 : -8'sd1;
                end

                if ((row == 0) || (col == ARRAY_SIZE-1) || (row == col)) begin
                    b_val = int'(((row + col) * 3) % 13) - 6;
                    item.b_matrix[row][col] = b_val[7:0];
                end
            end
        end
    endfunction

    function void fill_checkerboard(mini_tpu_item item);
        item.clear_matrices();
        item.case_name = "checkerboard_scale";

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                item.a_matrix[row][col] = ((row + col) % 2 == 0) ? 8'sd4 : -8'sd3;
                item.b_matrix[row][col] = ((row * col) % 2 == 0) ? -8'sd2 : 8'sd5;
            end
        end
    endfunction

endclass

`endif
