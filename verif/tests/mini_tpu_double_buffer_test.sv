`ifndef MINI_TPU_DOUBLE_BUFFER_TEST_SV
`define MINI_TPU_DOUBLE_BUFFER_TEST_SV

class mini_tpu_double_buffer_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_double_buffer_test)

    function new(string name = "mini_tpu_double_buffer_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item bank1_item;
        mini_tpu_item bank0_item;
        bit [31:0] cfg_data;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_DBUF_TEST", "Starting double-buffer preload test", UVM_LOW)

        bank1_item = mini_tpu_item::type_id::create("bank1_item");
        bank0_item = mini_tpu_item::type_id::create("bank0_item");
        bank1_item.set_identity();
        bank0_item.set_mixed_signed();

        // load_bank=1, compute_bank=0: fill bank1 without disturbing default bank0.
        expect_write_resp(ADDR_CFG, 32'h0000_0001, 4'h1, RESP_OKAY);
        expect_read_resp(ADDR_CFG, RESP_OKAY, cfg_data);
        if (cfg_data[1:0] !== 2'b01) begin
            `uvm_error("MINI_TPU_DBUF_TEST", $sformatf("CFG after selecting load bank1 = 0x%0h", cfg_data))
        end

        load_item(bank1_item);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, bank1_item.a_matrix[0][0]);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, bank1_item.b_matrix[0][0]);

        // load_bank=0, compute_bank=1: compute bank1 while preloading bank0.
        expect_write_resp(ADDR_CFG, 32'h0000_0002, 4'h1, RESP_OKAY);
        start_core();
        expect_busy_seen();
        load_item(bank0_item);
        poll_done();
        check_result(bank1_item);
        clear_done_sticky();

        // Now compute the tile that was preloaded into bank0 during the previous run.
        expect_write_resp(ADDR_CFG, 32'h0000_0000, 4'h1, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, bank0_item.a_matrix[0][0]);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, bank0_item.b_matrix[0][0]);
        start_core();
        poll_done();
        check_result(bank0_item);
        clear_done_sticky();

        `uvm_info("MINI_TPU_DBUF_TEST", "Double-buffer preload test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass

`endif
