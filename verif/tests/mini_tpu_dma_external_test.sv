`ifndef MINI_TPU_DMA_EXTERNAL_TEST_SV
`define MINI_TPU_DMA_EXTERNAL_TEST_SV

class mini_tpu_dma_external_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_dma_external_test)

    localparam bit [31:0] EXT_A_BASE = 32'h0000_1000;
    localparam bit [31:0] EXT_B_BASE = 32'h0000_2000;

    function new(string name = "mini_tpu_dma_external_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item item;
        bit [31:0] status;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();
        vif.ext_mem_clear();

        `uvm_info("MINI_TPU_DMA_EXTERNAL_TEST", "Starting external-memory DMA preload test", UVM_LOW)

        item = mini_tpu_item::type_id::create("item");
        item.set_mixed_signed();

        program_external_tile(item, EXT_A_BASE, EXT_B_BASE);

        expect_write_resp(ADDR_DMA_A_SRC_ADDR, EXT_A_BASE, 4'hf, RESP_OKAY);
        expect_write_resp(ADDR_DMA_B_SRC_ADDR, EXT_B_BASE, 4'hf, RESP_OKAY);
        expect_read_resp(ADDR_DMA_A_SRC_ADDR, RESP_OKAY, status);
        if (status !== EXT_A_BASE) begin
            `uvm_error("MINI_TPU_DMA_EXTERNAL_TEST",
                $sformatf("DMA A source descriptor mismatch actual=0x%0h expected=0x%0h", status, EXT_A_BASE))
        end

        expect_write_resp(ADDR_DMA_CFG, 32'h0000_000f, 4'h1, RESP_OKAY);
        env.cov.sample_dma(1, 3, 1, 0, 0, 0);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        poll_dma_done();

        expect_write_resp(ADDR_CFG, 32'h0000_0003, 4'h1, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, item.a_matrix[0][0]);
        check_matrix_low_byte(ADDR_B_BASE, 0, 0, item.b_matrix[0][0]);
        clear_dma_status();

        start_core();
        poll_done();
        check_result(item);
        clear_done_sticky();

        expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, status);
        if (status[2]) begin
            `uvm_error("MINI_TPU_DMA_EXTERNAL_TEST", $sformatf("DMA error sticky set at end status=0x%0h", status))
        end

        `uvm_info("MINI_TPU_DMA_EXTERNAL_TEST", "External-memory DMA preload test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

    task automatic program_external_tile(mini_tpu_item item, bit [31:0] a_base, bit [31:0] b_base);
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                vif.ext_mem_write_i8(ext_matrix_addr(a_base, row, col), item.a_matrix[row][col]);
                vif.ext_mem_write_i8(ext_matrix_addr(b_base, row, col), item.b_matrix[row][col]);
            end
        end
    endtask

    function automatic bit [31:0] ext_matrix_addr(bit [31:0] base, int unsigned row, int unsigned col);
        ext_matrix_addr = base + (((row * ARRAY_SIZE) + col) << 2);
    endfunction

endclass

`endif
