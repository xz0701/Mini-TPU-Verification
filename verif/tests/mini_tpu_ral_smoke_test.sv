`ifndef MINI_TPU_RAL_SMOKE_TEST_SV
`define MINI_TPU_RAL_SMOKE_TEST_SV

class mini_tpu_ral_smoke_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_ral_smoke_test)

    function new(string name = "mini_tpu_ral_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        uvm_status_e status;
        uvm_reg_data_t data;
        mini_tpu_item item;

        phase.raise_objection(this);
        wait_for_reset();

        `uvm_info("MINI_TPU_RAL_TEST", $sformatf("Starting %0dx%0d RAL frontdoor smoke", ARRAY_SIZE, ARRAY_SIZE), UVM_LOW)

        item = mini_tpu_item::type_id::create("item");
        item.set_identity();

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                env.ral_model.a_mem.write(status,
                                          matrix_index(row, col),
                                          {{24{item.a_matrix[row][col][7]}}, item.a_matrix[row][col]},
                                          UVM_FRONTDOOR);
                check_status(status, $sformatf("A[%0d][%0d] write", row, col));

                env.ral_model.b_mem.write(status,
                                          matrix_index(row, col),
                                          {{24{item.b_matrix[row][col][7]}}, item.b_matrix[row][col]},
                                          UVM_FRONTDOOR);
                check_status(status, $sformatf("B[%0d][%0d] write", row, col));
            end
        end

        env.ral_model.a_mem.read(status, 0, data, UVM_FRONTDOOR);
        check_status(status, "A[0][0] readback");
        if (data[7:0] !== item.a_matrix[0][0]) begin
            `uvm_error("MINI_TPU_RAL_TEST",
                $sformatf("A[0][0] readback mismatch actual=0x%0h expected=0x%0h",
                          data[7:0], item.a_matrix[0][0]))
        end

        env.ral_model.ctrl.write(status, 32'h0000_0001, UVM_FRONTDOOR);
        check_status(status, "CTRL.start write");

        poll_done_ral();

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                env.ral_model.c_mem.read(status, matrix_index(row, col), data, UVM_FRONTDOOR);
                check_status(status, $sformatf("C[%0d][%0d] read", row, col));
                if ($signed(data[31:0]) !== item.expected_at(row, col)) begin
                    `uvm_error("MINI_TPU_RAL_TEST",
                        $sformatf("C[%0d][%0d] mismatch actual=%0d expected=%0d",
                                  row, col, $signed(data[31:0]), item.expected_at(row, col)))
                end
            end
        end

        env.ral_model.ctrl.write(status, 32'h0000_0002, UVM_FRONTDOOR);
        check_status(status, "CTRL.clear_done write");

        `uvm_info("MINI_TPU_RAL_TEST", "RAL frontdoor smoke completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

    task automatic poll_done_ral();
        uvm_status_e status;
        uvm_reg_data_t data;

        for (int timeout = 0; timeout < 300; timeout++) begin
            env.ral_model.status.read(status, data, UVM_FRONTDOOR);
            check_status(status, "STATUS read");
            if (data[1]) begin
                return;
            end
            @(posedge vif.clk);
        end

        `uvm_error("MINI_TPU_RAL_TEST", "Timeout waiting for RAL STATUS.done")
    endtask

    function void check_status(uvm_status_e status, string op_name);
        if (status != UVM_IS_OK) begin
            `uvm_error("MINI_TPU_RAL_TEST", $sformatf("%s returned status %s", op_name, status.name()))
        end
    endfunction

    function automatic int unsigned matrix_index(int unsigned row, int unsigned col);
        matrix_index = (row * ARRAY_SIZE) + col;
    endfunction

endclass

`endif
