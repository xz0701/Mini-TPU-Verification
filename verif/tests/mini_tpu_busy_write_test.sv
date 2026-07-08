`ifndef MINI_TPU_BUSY_WRITE_TEST_SV
`define MINI_TPU_BUSY_WRITE_TEST_SV

class mini_tpu_busy_write_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_busy_write_test)

    function new(string name = "mini_tpu_busy_write_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item item;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_BUSY_TEST", "Starting busy-time write protection test", UVM_LOW)

        item = mini_tpu_item::type_id::create("item");
        item.set_identity();

        load_item(item);
        start_core();
        expect_write_resp(matrix_addr(ADDR_B_BASE, 0, 0), 32'h0000_007f, 4'h1, RESP_OKAY);

        poll_done();
        check_result(item);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, item.b_matrix[0][0]);
        clear_done_sticky();

        load_item(item);
        start_core();
        expect_write_resp(matrix_addr(ADDR_A_BASE, 0, 0), 32'h0000_007f, 4'h1, RESP_OKAY);

        poll_done();
        check_result(item);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, item.a_matrix[0][0]);
        clear_done_sticky();

        `uvm_info("MINI_TPU_BUSY_TEST", "Busy-time write protection test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass

`endif
