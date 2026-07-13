`ifndef MINI_TPU_DMA_TEST_SV
`define MINI_TPU_DMA_TEST_SV

class mini_tpu_dma_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_dma_test)

    function new(string name = "mini_tpu_dma_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item bank1_item;
        mini_tpu_item bank0_item;
        bit [31:0] status;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_DMA_TEST", "Starting DMA preload and ping-pong test", UVM_LOW)

        bank1_item = mini_tpu_item::type_id::create("bank1_item");
        bank0_item = mini_tpu_item::type_id::create("bank0_item");
        bank1_item.set_identity();
        bank0_item.set_mixed_signed();

        load_dma_source(bank1_item);
        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0007, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        poll_dma_done();

        expect_write_resp(ADDR_CFG, 32'h0000_0001, 4'h1, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, bank1_item.a_matrix[0][0]);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, bank1_item.b_matrix[0][0]);
        clear_dma_status();

        load_dma_source(bank0_item);
        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0006, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_CFG, 32'h0000_0002, 4'h1, RESP_OKAY);
        start_core();
        expect_busy_seen();
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);

        poll_done();
        check_result(bank1_item);
        clear_done_sticky();
        poll_dma_done();
        clear_dma_status();

        expect_write_resp(ADDR_CFG, 32'h0000_0000, 4'h1, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, bank0_item.a_matrix[0][0]);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, bank0_item.b_matrix[0][0]);
        start_core();
        poll_done();
        check_result(bank0_item);
        clear_done_sticky();

        expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, status);
        if (status[2]) begin
            `uvm_error("MINI_TPU_DMA_TEST", $sformatf("DMA error sticky set at end status=0x%0h", status))
        end

        `uvm_info("MINI_TPU_DMA_TEST", "DMA preload and ping-pong test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass

`endif
